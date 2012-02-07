# WARNING!!!  This class is little raw.  It will not disable any notifications or do not have import, export and sync time knowledge.  
# Check out google_contacts_importer for proper import, export or merge functionalities.

class Integrations::GoogleAccount < ActiveRecord::Base
  include Integrations::GoogleContactsUtil

  belongs_to :account
  belongs_to :sync_tag, :class_name => "Helpdesk::Tag"
  attr_protected :account_id, :sync_tag_id
  serialize :last_sync_status, Hash
  has_many :google_contact, :dependent => :destroy

  def self.find_or_create(params, account)
    id = params[:id]
    id = params[:integrations_google_account][:id] if id.blank?
    sync_tag_name = params[:integrations_google_account][:sync_tag]
    params[:integrations_google_account][:sync_tag] = sync_tag_name.blank? ? nil : account.tags.find_or_create_by_name(sync_tag_name)
    params[:integrations_google_account][:account] = account
    if id.blank?
      # The below line has to be removed, to support multiple google accounts for single account.
      goog_acc = Integrations::GoogleAccount.find(:first, :conditions => ["email=? and account_id=?", params[:integrations_google_account][:email], account]) unless params[:integrations_google_account][:email].blank?
    else
      goog_acc = Integrations::GoogleAccount.find(:first, :conditions => ["id=? and account_id=?", id, account])
    end
    if goog_acc.blank?
      goog_acc = Integrations::GoogleAccount.new(params[:integrations_google_account])
    else
      goog_acc.attributes = params[:integrations_google_account]
    end
    return goog_acc
  end

  def self.find_all_installed_google_accounts(account=nil)
    goog_cnt_app = Integrations::Application.find(:first, :conditions => {:name => "google_contacts"})
    conditions = ["installed_applications.application_id = ?", goog_cnt_app]
    unless account.blank?
      conditions = ["installed_applications.application_id = ? and installed_applications.account_id=?", goog_cnt_app, account]
    end
    Integrations::GoogleAccount.find(:all, 
                  :joins => "INNER JOIN installed_applications ON installed_applications.account_id=google_accounts.account_id", 
                  :select => "google_accounts.*, installed_applications.configs", :conditions => conditions)
  end

  def self.delete_all_google_accounts(account)
    Integrations::GoogleAccount.delete_all(["account_id = ?", account])
  end

  def fetch_all_google_groups(query_params=nil)
    google_account = self 
    token = google_account.token
    secret = google_account.secret

    goog_groups_url = google_groups_uri(google_account)
    unless query_params.blank?
      goog_groups_url = goog_groups_url+query_params 
    end
    access_token = prepare_access_token(token, secret)
    updated_groups_xml = access_token.get(goog_groups_url).body
    puts goog_groups_url + "   " + updated_groups_xml
    updated_groups_hash = XmlSimple.xml_in(updated_groups_xml)['entry']
    puts "#{updated_groups_hash.length} groups from google account has been fetched with query #{query_params}. #{google_account.email}"
    google_groups_arr = []
    updated_groups_hash.each {|group_hash|
      google_group = Integrations::GoogleGroup.new
      google_group.group_id = Integrations::GoogleContactsUtil.parse_id(group_hash['id'])
      google_group.name = group_hash['content']['content']
      google_groups_arr.push(google_group)
    }
    return google_groups_arr
  end

  def fetch_all_google_contacts()
    return find_latest_google_contacts("none", Time.at(0)) # To fetch all the contacts change the last synced time 0.
  end

  # If group_id is null or empty then the group_id configured to sync will be used.  Use 'none' as group_id to fetch complete contact list.
  def fetch_latest_google_contacts(group_id=nil, last_sync_time=nil, max_results=10000)
    query_params = ""
    last_sync_time = self.last_sync_time if last_sync_time.blank?
    if group_id.blank?
      group_id = self.sync_group_id
    end
    if group_id == "none"
      group_id = nil 
    end

    # While syncing first ever time, the time would be 1970:01:01.
    sync_time_str = last_sync_time.gmtime.strftime("%Y-%m-%dT%H:%M:%S")
    query_params = "?showdeleted&updated-min="+ sync_time_str  # url to fetch only the modified contacts since last sync time. showdeleted fetches the deleted user as well. 
    query_params = query_params + "&group="+google_group_uri(self.email, group_id) unless group_id.blank?
    query_params = "#{query_params}&max-results#{max_results}"
    return fetch_google_contacts(query_params)
  end

  def batch_update_google_contacts(db_contacts)
    stats = [[0,0,0],[0,0,0]]
    db_contacts_slices = db_contacts.each_slice(100).to_a # Batch requests are limited to 100 operations at a time by Google.
    slice_no = 1
    db_contacts_slices.each { |db_contacts_slice|
      begin
        batch_operation_xml = "<?xml version='1.0' encoding='UTF-8'?> <feed xmlns='http://www.w3.org/2005/Atom' xmlns:gContact='http://schemas.google.com/contact/2008' xmlns:gd='http://schemas.google.com/g/2005' xmlns:batch='http://schemas.google.com/gdata/batch'>"
        batch_operation_xml << update_google_contacts(db_contacts_slice, true)
        batch_operation_xml << "</feed>"
        puts "batch_operation_xml #{batch_operation_xml}"
        uri = google_contact_batch_uri(self)
        access_token = prepare_access_token(self.token, self.secret)
        batch_response = access_token.post(uri, batch_operation_xml, {"Content-Type" => "application/atom+xml", "GData-Version" => "3.0", "If-Match" => "*"})
        stats = handle_batch_response(batch_response, stats)
        slice_no += 1
      rescue => e
        puts "Problem in exporting google contacts slice no #{slice_no}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      end
    }
    return stats
  end

  # If batch true is passed then just the batch xml will be returned.
  def update_google_contacts(db_contacts, batch=false)
    batch_xml = ""
    db_contacts.each do |db_contact|
      begin
        if db_contact.deleted and self.overwrite_existing_user # deleted
          puts "Deleting contact #{db_contact.email} in google for account #{db_contact.account_id}."
          response = delete_google_contact(db_contact, batch)
        elsif db_contact.google_id.blank?
          puts "Adding contact #{db_contact.email} in google for account #{db_contact.account_id}."
          response = add_google_contact(db_contact, batch)
        else self.overwrite_existing_user# updated
          puts "Updating contact #{db_contact.email} in google for account #{db_contact.account_id}."
          response = update_google_contact(db_contact, batch)
        end
        batch_xml << response unless response.blank?
      rescue => e
        puts "Problem in exporting google contact #{db_contact.email}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      end
    end
    return batch_xml;
  end

  def is_primary?
    !self.id.blank?
  end

  def make_it_non_primary
    self.id = nil
  end

  private
    def handle_batch_response(batch_response, stats)
      if batch_response.code == "200"
        batch_response_xml = batch_response.body
        batch_response_hash = XmlSimple.xml_in(batch_response_xml)
        puts "stats #{stats}  \n Converted batch_response_hash #{batch_response_hash.inspect}"
        batch_response_hash = batch_response_hash['entry']
        batch_response_hash.each {|response|
          begin
            status_code = response['status'][0]['code']
            id = response['id']
            operation = id[1]
            if status_code == "200" || status_code == "201"
              if operation == CREATE
                email = response['email'][0]['address']
                # If create contact is successful update the id in the database.
                goog_id = Integrations::GoogleContactsUtil.parse_id(id)
                db_contact = find_user_by_email(email)
                updated = update_google_contact_id(db_contact, goog_id)
                stats[0][0]+=1
                puts "Newly added contact id #{goog_id} and status #{updated} #{stats}"
              else
                update_google_contact_id(db_contact, goog_id) if db_contact.google_contact.blank?
                operation == DELETE ? stats[0][2]+=1 : stats[0][1]+=1
                puts "Successfully #{operation}d contact with id #{id} and status_code #{status_code} #{stats}."
              end
            elsif status_code == "404" && operation == UPDATE
              goog_id = Integrations::GoogleContactsUtil.parse_id(id)
              puts "Contact does not exist. Adding the contact #{id}"
              db_contact = find_user_by_google_id(goog_id)
              add_google_contact(db_contact) # This is not a batch operation. One entry will be added.
            else
              operation == CREATE ? (stats[1][0]+=1) : (operation == DELETE ? stats[1][2]+=1 : stats[1][1]+=1)
              puts "Error in #{operation}. For #{email}, the response #{response.inspect}"
            end
          rescue => e
            puts "ERROR in processing single batch_response_xml.\n#{response.inspect}.  \n#{e.message}\n#{e.backtrace.join("\n")}"
          end
        }
      else
        puts "Failed to export the Google contacts through batch operation. #{batch_response.inspect}"
      end
      return stats
    end

    def add_google_contact(db_contact, batch=false)
  #      puts "add_google_contact "+db_contact.inspect
      google_account = self
      if batch
        return covert_to_batch_contact_xml(db_contact, CREATE)
      else
        goog_contact_entry_xml += covert_to_contact_xml(db_contact)
#        puts "goog_contact_entry_xml #{goog_contact_entry_xml}"
        goog_contacts_url = google_contact_uri(google_account)
        access_token = prepare_access_token(google_account.token, google_account.secret)
        response = access_token.post(goog_contacts_url, goog_contact_entry_xml, {"Content-Type" => "application/atom+xml", "GData-Version" => "3.0"})
        puts "Adding contact #{db_contact}, response #{response.inspect}"
        if response.code == "200" || response.code == "201"
          # If create contact is successful update the id in the database.
          updated_contact_hash = XmlSimple.xml_in(response.body)
          goog_id = Integrations::GoogleContactsUtil.parse_id(updated_contact_hash['id'])
          updated = update_google_contact_id(db_contact, goog_id)
          puts "Newly added contacts id #{goog_id}, updated #{updated}"
        end
      end
    end

    def update_google_contact(db_contact, batch=false)
      google_account = self 
      goog_contact_id = db_contact.google_id
      #TODO If the google contact id is not available in db try fetching the contact using email (CURRENTLY NOT SUPPORTED BY GOOGLE API).
      # If the goog_contact_id is blank then assume the user itself dose not exist in the google contact. Create a new user.
      if goog_contact_id.blank?
        add_google_contact(db_contact, batch)
      else
        # Update the user detail in google contacts
        group_uri = nil
        group_uri = google_group_uri(google_account.email, google_account.sync_group_id) unless google_account.sync_group_id.blank?
        if batch
          return covert_to_batch_contact_xml(db_contact, UPDATE)
        else
          goog_contact_entry_xml = covert_to_contact_xml(db_contact)
          goog_contacts_url = google_contact_uri(google_account)+"/"+goog_contact_id
    #        puts goog_contact_entry_xml +" "+goog_contacts_url 
          access_token = prepare_access_token(google_account.token, google_account.secret)
          response = access_token.put(goog_contacts_url, goog_contact_entry_xml, {"Content-Type" => "application/atom+xml", "GData-Version" => "3.0", "If-Match" => "*"})
          puts "Updating contact #{db_contact}, response #{response.inspect}"
          if response.code == "200" || response.code == "201"
            puts "Successfully updated contact #{goog_contact_id}"
            #TODO update the google_id if the google_contact is not yet created for this db_contact.
          elsif response.code == "404"  # If the user does not found.
            puts "Contact does not exist. Adding the contact #{goog_contact_id}"
            add_google_contact(db_contact)
          end
        end
      end
    end

    def delete_google_contact(db_contact, batch=false)
      google_account = self 
      goog_contact_id = db_contact.google_id
      #TODO If the google contact id is not available in db try fetching the contact using email (CURRENTLY NOT SUPPORTED BY GOOGLE API).
      unless goog_contact_id.blank?
        if batch
          return covert_to_batch_contact_xml(db_contact, DELETE)
        else
          goog_contacts_url = google_contact_uri(google_account)+"/"+goog_contact_id
          access_token = prepare_access_token(google_account.token, google_account.secret)
          response = access_token.delete(goog_contacts_url, {"If-Match" => "*"})
          puts "Deleting contact #{db_contact}, response #{response.inspect}"
        end
      end
    end

    def fetch_google_contacts_by_id(id)
      fetch_google_contacts("/"+id)
    end

    def fetch_google_contacts(query_params)
      google_account = self
      token = google_account.token
      secret = google_account.secret

      # Text handling seems to handle huge contacts list efficiently instead of xml objects.
      goog_contacts_url = google_contact_uri(google_account)
      unless query_params.blank?
        goog_contacts_url = goog_contacts_url+query_params 
      end
      access_token = prepare_access_token(token, secret)
      updated_contact_xml = access_token.get(goog_contacts_url).body
#      puts goog_contacts_url + "   " + updated_contact_xml
      google_users = []
      begin
        doc = REXML::Document.new(updated_contact_xml)   
        doc.elements.each('feed/entry') { |contact_entry_element|
          converted_user = convert_to_user(contact_entry_element)
          google_users.push(converted_user) unless (converted_user.blank? or converted_user.email.blank?)
        }
      rescue => e
        puts "Error: No contact fetched. #{e.inspect}"+updated_contact_xml
      end
      puts "#{google_users.length} users from google account has been fetched with query #{query_params}. Email #{google_account.email}"
      return google_users
    end

    def covert_to_batch_contact_xml(user, operation)
      goog_contacts_url = google_contact_uri(self)
      if operation != CREATE
        goog_contacts_url += "/"+user.google_id
      end
      etag_xml = ""#operation == CREATE ? "" : " gd:etag='#{operation}ContactEtag'"
      xml_str = "<entry#{etag_xml}> <batch:id>#{operation}</batch:id> <batch:operation type='#{operation == CREATE ? "insert" : operation}'/> <category scheme='http://schemas.google.com/g/2005#kind' term='http://schemas.google.com/contact/2008#contact'/>"
      xml_str << contact_xml(user) unless operation == DELETE
      xml_str << "</entry>"
#      puts "xml_str #{xml_str}"
      return xml_str
    end

    def covert_to_contact_xml(user)
      # Creating xml string directly with out using xml object.  Works faster.
      xml_str =   "<atom:entry xmlns:atom='http://www.w3.org/2005/Atom' xmlns:gd='http://schemas.google.com/g/2005' xmlns:gContact='http://schemas.google.com/contact/2008'> <atom:category scheme='http://schemas.google.com/g/2005#kind' term='http://schemas.google.com/contact/2008#contact'/>"
      xml_str << contact_xml(user)
      xml_str << "</atom:entry>"
    end

    def contact_xml(user)
      xml_str = ""
      # This will make sure the entries present in the google is preserved without touching them
      trimmed_xml = trimmed_contact_xml(user, self.sync_group_id)
      trimmed_xml.elements.each {|ele|
        xml_str << ele.to_s
      }
      # Now append the overwritten entries
      USER_FILEDS_TO_GOOGLE_XML_MAPPING.each { |prop_name, goog_prop_xml|
        if(!goog_prop_xml.blank? and user.has_attribute?(prop_name))
          prop_value = user.read_attribute(prop_name)
          unless prop_value.blank?
            prop_value = prop_value.to_s.to_xs
            xml_str << goog_prop_xml.gsub("$"+prop_name, prop_value)
          end
        end
      }
      xml_str << " <gd:organization rel='http://schemas.google.com/g/2005#other'><gd:orgName>#{user.customer.name}</gd:orgName></gd:organization>" unless user.customer.blank?
      unless self.sync_group_id.blank?
        group_uri = google_group_uri(self.email, self.sync_group_id) 
        xml_str << " <gContact:groupMembershipInfo deleted='false' href='#{group_uri}'/>"
      end
    end

    def prepare_access_token(oauth_token, oauth_token_secret)
      # TODO get the below detail from yml config
      oauth_s = Integrations::GoogleContactsUtil.get_oauth_keys
      consumer = OAuth::Consumer.new(oauth_s[0], oauth_s[1],
          { :site => "https://www.google.com/"})
      # now create the access token object from passed values
      token_hash = { :oauth_token => oauth_token,
                                   :oauth_token_secret => oauth_token_secret
                               }
      access_token = OAuth::AccessToken.from_hash(consumer, token_hash )
      return access_token
    end

    def google_contact_uri(google_account)
      return "http://www.google.com/m8/feeds/contacts/"+google_account.email+"/full" # No need to append '/' at the end. The url would look elegant if you append any params in this url. 
    end

    def google_contact_batch_uri(google_account)
      return "https://www.google.com/m8/feeds/contacts/#{google_account.email}/full/batch"
    end

    def google_groups_uri(google_account)
      return "http://www.google.com/m8/feeds/groups/"+google_account.email+"/full" # No need to append '/' at the end. The url would look elegant if you append any params in this url. 
    end

    def google_group_uri(email, group_id)
      return "http://www.google.com/m8/feeds/groups/"+email+"/base/"+group_id # No need to append '/' at the end. The url would look elegant if you append any params in this url. 
    end

    # This method will take care of creating(add) or fetch/updating(edit) or setting delete flag(delete) an user from google contact entry xml. 
    def convert_to_user(contact_entry_ele)
      goog_contact_detail = parse_user_xml(contact_entry_ele)
      user = nil
      # Get the user based on his primary email address
      user = find_user_by_email(goog_contact_detail[:primary_email]) unless goog_contact_detail[:primary_email].blank?

      # user is not found using email then fetch user based on his google id. mostly used for deleted users in google contacts.
      user = find_user_by_google_id(goog_contact_detail[:google_id]) if user.blank? and self.is_primary?

      # Create the user if not able to fetch with any of the above options
      user = User.new if user.blank?
      # Google id based search and updating google_id will only happen for the primary google account.
      if self.is_primary?
        user.google_contact = GoogleContact.new(:google_account=>self) if user.google_contact.blank?
        user.google_contact.google_xml = goog_contact_detail[:google_xml]
        user.google_contact.google_id = goog_contact_detail[:google_id]
        user.google_contact.google_group_ids = goog_contact_detail[:google_group_ids]
      end

      # orgName would be considered as customer name.  If the name is removed then the customer will not be associated
      orgName = goog_contact_detail[:orgName]
      if orgName.blank?
        user.customer = nil
      else
        customer = Customer.find_by_name(orgName)
        if customer.blank?
          customer = Customer.new
          customer.name = orgName
        end
        user.customer = customer
      end

      user.add_tag self.sync_tag # Tag the user with the sync_tag
#      puts "Complete goog_contact_detail "+goog_contact_detail.inspect + ", sync_tag_id #{sync_tag_id}, user detail "+user.inspect

      # Set the values for the user.
      goog_contact_detail.each { |key, value|
        db_attr = GOOGLE_FIELDS_TO_USER_FILEDS_MAPPING[key]
        user.write_attribute(db_attr, value) unless (db_attr.blank? or value.blank?)
      }

      user.account = account if user.account.blank?
      user.customer.account = account unless user.customer.blank? || !user.customer.account.blank?
#      puts "Converted user.  User id #{user.id}.  Delete flag #{user.deleted}."
      return user
    end

    def update_google_contact_id(db_contact, goog_id)
      if db_contact.blank?
        return false
      else
        if db_contact.google_contact.blank?
          db_contact.google_contact = GoogleContact.new(:google_account=>self)
        end
        db_contact.google_contact.google_id = goog_id
        db_contact.save!
      end
    end

    def find_user_by_email(email)
      self.account.all_users.find_by_email(email, :include=>[:tags, :google_contact]) unless email.blank?
    end

    def find_user_by_google_id(google_id)
      self.account.all_users.find(:first, :include=>[:tags], :joins=>"INNER JOIN google_contacts ON google_contacts.user_id=users.id", 
                                  :conditions=>["google_contacts.google_id = ? and google_contacts.google_account_id = ?", google_id, self.id]) unless google_id.blank?
    end

    CREATE="create"
    RETRIEVE="retrieve"
    UPDATE="update"
    DELETE="delete"

end
