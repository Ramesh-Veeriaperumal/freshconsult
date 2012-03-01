# WARNING!!!  This class is little raw.  It do not disable any notifications, do not handle paging completely or do not have import, export and sync time knowledge.  
# Check out google_contacts_importer for proper import, export or merge functionalities.

class Integrations::GoogleAccount < ActiveRecord::Base
  include Integrations::GoogleContactsUtil

  belongs_to :account
  belongs_to :sync_tag, :class_name => "Helpdesk::Tag"
  attr_protected :account_id, :sync_tag_id
  serialize :last_sync_status, Hash
  has_many :google_contacts, :dependent => :destroy
  attr_accessor :last_sync_index, :import_groups, :donot_update_sync_time # Non persisted property used only for importing.

  def self.find_or_create(params, account)
    id = params[:id]
    id = params[:integrations_google_account][:id] if id.blank?
    sync_tag_name = params[:integrations_google_account][:sync_tag]
    params[:integrations_google_account][:sync_tag] = sync_tag_name.blank? ? nil : account.tags.find_or_create_by_name(sync_tag_name)
    params[:integrations_google_account][:account] = account
    if id.blank?
      # The below line has to be removed, to support multiple sync for same google account.
      goog_acc = Integrations::GoogleAccount.find(:first, :conditions => ["email=? and account_id=?", params[:integrations_google_account][:email], account]) unless params[:integrations_google_account][:email].blank?
    else
      goog_acc = Integrations::GoogleAccount.find(:first, :conditions => ["id=? and account_id=?", id, account])
    end
    if goog_acc.blank?
      goog_acc = Integrations::GoogleAccount.new(params[:integrations_google_account])
    end
    goog_acc.attributes = params[:integrations_google_account]
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

  def create_google_group(group_name)
    xml_to_send = CREATE_GROUP_XML.gsub("$group_name", group_name)
    access_token = prepare_access_token(self.token, self.secret)
    response = access_token.post(google_groups_uri(self), xml_to_send, {"Content-Type" => "application/atom+xml", "GData-Version" => "3.0"})
    Rails.logger.debug "response #{response.inspect}"
    if response.code == "200" || response.code == "201"
      # If create group is successful return the id
      updated_group_hash = XmlSimple.xml_in(response.body)
      goog_grp_id = Integrations::GoogleContactsUtil.parse_id(updated_group_hash['id'])
      return goog_grp_id
    end
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
    updated_groups_hash = XmlSimple.xml_in(updated_groups_xml)['entry'] || []
    Rails.logger.debug "#{updated_groups_hash.length} groups from google account has been fetched with query #{query_params}. #{google_account.email}"
    google_groups_arr = []
    updated_groups_hash.insert(0, 'id'=>['base/6'], 'content'=>{'content'=>'My Contacts'})
    updated_groups_hash.each {|group_hash|
      google_group = Integrations::GoogleGroup.new
      google_group.group_id = Integrations::GoogleContactsUtil.parse_id(group_hash['id'])
      google_group.name = group_hash['content']['content']
      google_groups_arr.push(google_group)
    }
    return google_groups_arr
  end

  def fetch_all_google_contacts()
    return fetch_latest_google_contacts("none", Time.at(0)) # To fetch all the contacts change the last synced time 0.
  end

  def reset_start_index
    self.last_sync_index = 0
  end

  # If group_id is null or empty then the group_id configured to sync will be used.  Use 'none' as group_id to fetch complete contact list.
  # group_id will be ignored in case 'import_groups' has any groups to import.
  # This method uses paging. If the number of contacts returned is more than max_results (By default 1000), it is calling method's 
  #      responsibility to call this method again to fetch the next page.
  #      If 'import_groups' is used then the imported group will be removed.  In that case it is calling methods 
  #      responsibility to call this method again until the 'import_groups' is empty.
  def fetch_latest_google_contacts(max_results=1000, group_id=nil, last_sync_time=nil)
    query_params = ""
    last_sync_time = self.last_sync_time if last_sync_time.blank?
    if group_id.blank?
      group_id = self.sync_group_id
    end
    if group_id == "none"
      group_id = nil 
    end

    # While syncing first ever time, the time would be 1970:01:01.
    show_deleted = false ? "&showdeleted" : ""  # deletion handling is Disabled for now. Remove this check to enable it.
    agg_g_cnts = []
    self.last_sync_index = 0 if self.last_sync_index.blank?
    if self.import_groups.blank?
      sync_time_str = last_sync_time.gmtime.strftime("%Y-%m-%dT%H:%M:%S")
      query_params = "?updated-min="+ sync_time_str  # url to fetch only the modified contacts since last sync time. showdeleted fetches the deleted user as well. 
      query_params = query_params + "&group=#{google_group_uri(self.email, group_id)}" unless group_id.blank?
      query_params = "#{query_params}#{show_deleted}&max-results=#{max_results+1}&start-index=#{self.last_sync_index+1}"
      agg_g_cnts = fetch_google_contacts(query_params)
      self.last_sync_index = agg_g_cnts.length
    else
      remaining_results = max_results
      start_index = self.last_sync_index
      self.import_groups.delete_if { |g_group_id|
        if agg_g_cnts.length > max_results
          false
        else
          query_params = "?group=#{google_group_uri(self.email, g_group_id)}#{show_deleted}&max-results=#{remaining_results+1}&start-index=#{start_index+1}"
          fetched_g_cnts = fetch_google_contacts(query_params)
          self.last_sync_index += fetched_g_cnts.length
          start_index = 0
          # Aggregate the fetched google contacts. 
          fetched_g_cnts.each {|f_g_cnt|
            agg_g_cnts.push(f_g_cnt)
          }
          # Manipulate the remaining_results
          remaining_results -= fetched_g_cnts.length
          true
        end
      }
    end
    agg_g_cnts
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
        # puts "batch_operation_xml #{batch_operation_xml}"
        uri = google_contact_batch_uri(self)
        access_token = prepare_access_token(self.token, self.secret)
        batch_response = access_token.post(uri, batch_operation_xml, {"Content-Type" => "application/atom+xml", "GData-Version" => "3.0", "If-Match" => "*"})
        stats = handle_batch_response(batch_response, stats)
        slice_no += 1
      rescue => e
        Rails.logger.error "Problem in exporting google contacts slice no #{slice_no}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      end
    }
    return stats
  end

  # If batch true is passed, only the xml will be returned.
  def update_google_contacts(db_contacts, batch=false)
    batch_xml = ""
    db_contacts.each do |db_contact|
      begin
        if db_contact.deleted and self.overwrite_existing_user # deleted
          Rails.logger.debug "Deleting contact #{db_contact.email} in google for account #{db_contact.account_id}."
          response = delete_google_contact(db_contact, batch)
        elsif !fetch_current_account_contact(db_contact)
          Rails.logger.debug "Adding contact #{db_contact.email} in google for account #{db_contact.account_id}."
          response = add_google_contact(db_contact, batch)
        else self.overwrite_existing_user# updated
          Rails.logger.debug "Updating contact #{db_contact.email} in google for account #{db_contact.account_id}."
          response = update_google_contact(db_contact, batch)
        end
        batch_xml << response unless response.blank?
      rescue => e
        Rails.logger.error "Problem in exporting google contact #{db_contact.email}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      end
    end
    return batch_xml;
  end

  private
    def handle_batch_response(batch_response, stats)
      if batch_response.code == "200"
        batch_response_xml = batch_response.body
        batch_response_hash = XmlSimple.xml_in(batch_response_xml)
        # puts "stats #{stats}  \n Converted batch_response_hash #{batch_response_hash.inspect}"
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
                Rails.logger.info "Newly added contact id #{goog_id} and status #{updated} #{stats}"
              else
                update_google_contact_id(db_contact, goog_id)
                operation == DELETE ? stats[0][2]+=1 : stats[0][1]+=1
                Rails.logger.info "Successfully #{operation}d contact with id #{id} and status_code #{status_code} #{stats}."
              end
            elsif status_code == "404" && operation == UPDATE
              goog_id = Integrations::GoogleContactsUtil.parse_id(id)
              db_contact = find_user_by_google_id(goog_id)
              Rails.logger.info "Contact does not exist. Adding the contact #{db_contact} with google id #{goog_id}"
              add_google_contact(db_contact) # This is not a batch operation. One entry will be added.
            else
              operation == CREATE ? (stats[1][0]+=1) : (operation == DELETE ? stats[1][2]+=1 : stats[1][1]+=1)
              Rails.logger.error "Error in #{operation}. For #{email}, the response #{response.inspect}"
            end
          rescue => e
            Rails.logger.error "ERROR in processing single batch_response_xml.\n#{response.inspect}.  \n#{e.message}\n#{e.backtrace.join("\n")}"
          end
        }
      else
        Rails.logger.error "Failed to export the Google contacts through batch operation. #{batch_response.inspect}"
      end
      return stats
    end

    def add_google_contact(db_contact, batch=false)
  #      puts "add_google_contact "+db_contact.inspect
      google_account = self
      if batch
        return covert_to_batch_contact_xml(db_contact, CREATE)
      else
        goog_contact_entry_xml = covert_to_contact_xml(db_contact)
        goog_contacts_url = google_contact_uri(google_account)
        access_token = prepare_access_token(google_account.token, google_account.secret)
        response = access_token.post(goog_contacts_url, goog_contact_entry_xml, {"Content-Type" => "application/atom+xml", "GData-Version" => "3.0"})
        Rails.logger.debug "Adding contact #{db_contact}, response #{response.inspect}"
        if response.code == "200" || response.code == "201"
          # If create contact is successful update the id in the database.
          updated_contact_hash = XmlSimple.xml_in(response.body)
          goog_id = Integrations::GoogleContactsUtil.parse_id(updated_contact_hash['id'])
          updated = update_google_contact_id(db_contact, goog_id)
          Rails.logger.info "Newly added contacts id #{goog_id}, updated #{updated}"
        end
      end
    end

    def update_google_contact(db_contact, batch=false)
      google_account = self 
      goog_contact_id = fetch_current_account_contact(db_contact).google_id
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
          Rails.logger.debug "Updating contact #{db_contact}, response #{response.inspect}"
          if response.code == "200" || response.code == "201"
            Rails.logger.info "Successfully updated contact #{goog_contact_id}"
            #TODO update the google_id if the google_contact is not yet created for this db_contact.
          elsif response.code == "404"  # If the user does not found.
            Rails.logger.info "Contact does not exist. Adding the contact #{goog_contact_id}"
            add_google_contact(db_contact)
          end
        end
      end
    end

    def delete_google_contact(db_contact, batch=false)
      google_account = self 
      goog_contact_id = fetch_current_account_contact(db_contact).google_id
      #TODO If the google contact id is not available in db try fetching the contact using email (CURRENTLY NOT SUPPORTED BY GOOGLE API).
      unless goog_contact_id.blank?
        if batch
          return covert_to_batch_contact_xml(db_contact, DELETE)
        else
          goog_contacts_url = google_contact_uri(google_account)+"/"+goog_contact_id
          access_token = prepare_access_token(google_account.token, google_account.secret)
          response = access_token.delete(goog_contacts_url, {"If-Match" => "*"})
          Rails.logger.info "Deleted contact #{db_contact}, response #{response.inspect}"
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
      updated_contact_xml = access_token.get(goog_contacts_url, "GData-Version" => "3.0").body
      # Rails.logger.debug goog_contacts_url + "   " + updated_contact_xml
      google_users = []
      begin
        doc = REXML::Document.new(updated_contact_xml)
        new_company_list = {}
        doc.elements.each('feed/entry') { |contact_entry_element|
          begin
            converted_user = convert_to_user(contact_entry_element, new_company_list)
            google_users.push(converted_user)
          rescue => e
            google_users.push(nil) # In case any exception occurs just store nil value for giving the correct number contacts fetched.
            Rails.logger.error "Error in processing a contact. contact_entry_element #{contact_entry_element.inspect}:  #{e.inspect}"
          end
        }
      rescue => e
        Rails.logger.error "Error in parsing the xml: #{updated_contact_xml}.  #{e.inspect}"
      end
      Rails.logger.info "#{google_users.length} users from google account has been fetched with query #{query_params}. Email #{google_account.email}"
      return google_users
    end

    def covert_to_batch_contact_xml(user, operation)
      goog_contacts_url = google_contact_uri(self)
      if operation != CREATE
        goog_contacts_url += "/"+fetch_current_account_contact(user).google_id
      end
      etag_xml = ""#operation == CREATE ? "" : " gd:etag='#{operation}ContactEtag'"
      xml_str = "<entry#{etag_xml}> <batch:id>#{operation}</batch:id> <batch:operation type='#{operation == CREATE ? "insert" : operation}'/> <id>#{goog_contacts_url}</id> <category scheme='http://schemas.google.com/g/2005#kind' term='http://schemas.google.com/contact/2008#contact'/>"
      xml_str << contact_xml(user) unless operation == DELETE
      xml_str << "</entry>"
#      puts "xml_str #{xml_str}"
      return xml_str
    end

    def covert_to_contact_xml(user)
      # Creating xml string directly with out using xml object.  Works faster.
      xml_str =   "<atom:entry xmlns:atom='http://www.w3.org/2005/Atom' xmlns:gd='http://schemas.google.com/g/2005' xmlns:gContact='http://schemas.google.com/contact/2008'> <category term='http://schemas.google.com/contact/2008#contact' scheme='http://schemas.google.com/g/2005#kind'/>"
      xml_str << contact_xml(user)
      xml_str << "</atom:entry>"
    end

    def contact_xml(user)
      xml_str = ""
      # Append the overwritten entries
      USER_FILEDS_TO_GOOGLE_XML_MAPPING.each { |prop_name, goog_prop_xml|
        if(!goog_prop_xml.blank? and user.has_attribute?(prop_name))
          prop_value = user.read_attribute(prop_name)
          unless prop_value.blank?
            prop_value = prop_value.to_s.to_xs
            xml_str << goog_prop_xml.gsub("$"+prop_name, prop_value)
          end
        end
      }
      # Now make sure the entries present in the original google xml is preserved without touching them.
      trimmed_xml = trimmed_contact_xml(user, fetch_current_account_contact(user), self.sync_group_id)
      unless trimmed_xml.blank?
        trimmed_xml.elements.each {|ele|
          xml_str << ele.to_s
        }
      end
      # Overwrite other data in DB.
      xml_str << " <gd:organization rel='http://schemas.google.com/g/2005#other'><gd:orgName>#{user.customer.name}</gd:orgName></gd:organization>" unless user.customer.blank?
      unless self.sync_group_id.blank?
        group_uri = google_group_uri(self.email, self.sync_group_id) 
        xml_str << " <gContact:groupMembershipInfo deleted='false' href='#{group_uri}'/>"
      end
      xml_str
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
    def convert_to_user(contact_entry_ele, new_company_list={})
      goog_contact_detail = parse_user_xml(contact_entry_ele)
      user = nil
      # Get the user based on his primary email address
      user = find_user_by_email(goog_contact_detail[:primary_email]) unless goog_contact_detail[:primary_email].blank?

      # user is not found using email then fetch user based on his google id. mostly used for deleted users in google contacts.
      user = find_user_by_google_id(goog_contact_detail[:google_id]) if user.blank?

      # Create the user if not able to fetch with any of the above options
      user = User.new if user.blank?
      if user.google_contacts.blank?
        user.google_contacts.build(:google_account=>self) # Will not persist the data in DB even if new_record? is true.
      end
      gcnt = fetch_current_account_contact(user)
      gcnt.google_xml = goog_contact_detail[:google_xml]
      gcnt.google_id = goog_contact_detail[:google_id]
      gcnt.google_group_ids = goog_contact_detail[:google_group_ids]

      # orgName would be considered as customer name.  If the name is removed then the customer will not be associated
      orgName = goog_contact_detail[:orgName]
      if orgName.blank?
        user.customer = nil
      else
        customer = new_company_list[orgName]
        customer = account.customers.find_by_name(orgName) if customer.blank?
        if customer.blank?
          customer = account.customers.new
          customer.name = orgName
          new_company_list[orgName] = customer
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
        g_cnt = fetch_current_account_contact(db_contact)
        if g_cnt
          return false if g_cnt.google_id = goog_id
        else
          g_cnt = GoogleContact.new(:google_account=>self)
          db_contact.google_contacts.push(g_cnt)
        end
        g_cnt.google_id = goog_id
        db_contact.save!
      end
    end

    def find_user_by_email(email)
      self.account.all_users.find_by_email(email, :include=>[:tags, :google_contacts]) unless email.blank?
    end

    def find_user_by_google_id(google_id)
      self.account.all_users.first(:include=>[:tags], :joins=>"INNER JOIN google_contacts ON google_contacts.user_id=users.id", 
                                  :conditions=>["google_contacts.google_id = ? and google_contacts.google_account_id = ?", google_id, self.id]) unless google_id.blank?
    end

    def fetch_current_account_contact(db_contact)
      db_contact.google_contacts.each {|g_cnt|
        return g_cnt if g_cnt.google_account_id == self.id
      }
      return nil
    end

    CREATE="create"
    RETRIEVE="retrieve"
    UPDATE="update"
    DELETE="delete"

    CREATE_GROUP_XML = %{<atom:entry xmlns:atom='http://www.w3.org/2005/Atom' xmlns:gd="http://schemas.google.com/g/2005"> <atom:category scheme="http://schemas.google.com/g/2005#kind" term="http://schemas.google.com/contact/2008#group"/> <atom:title type="text">$group_name</atom:title> </atom:entry>}
end
