module Integrations::GoogleContactsUtil
  include Integrations::Constants

  NilClass.class_eval do
    # define each method in the Nil class.  So that no need to check the blank every time before iterating.
    def each
      # do nothing. will not iterate the loop.
    end

    def length
      0
    end

    def end_with?(str)
      false
    end

    # below does nothing. will return nil. but do not throw error.
    def value
    end

    def attribute
    end
=begin
    def method_missing(meth_name, *args, &block)
      meth_name = meth_name.to_s
      matched = /(.*)_\?/.match(meth_name)
      if matched.blank?
        raise NoMethodError, "undefined method `#{meth_name}' for #{self.to_s}"
      else
        return nil
      end
    end
=end
  end

  def self.parse_id(goog_id_uri)
    matched_goog_id = /\[*base\/(.*)/.match(goog_id_uri[0]) unless goog_id_uri.blank? # looking for pattern 'any chars/base/<id>'
    return matched_goog_id[1] unless matched_goog_id.blank?
  end

  def self.get_prime_sec_email(contact_xml_as_hash)
    primary_email = nil
    second_email = nil
    contact_xml_as_hash['email'].each { |contact_emails|
      is_primary = contact_emails['primary']
      unless is_primary.blank? || is_primary != "true"
        primary_email = contact_emails['address']
      else
        second_email = contact_emails['address']
      end
    }
    return primary_email, second_email
  end

  def self.get_oauth_keys
    if Rails.env.production?
      ['freshdesk.com', 'f7NgGAv6TKqew3O5Xb85SadF']
    elsif Rails.env.staging?
      ['freshpo.com', 'mZ4Mvav/PzfC5X2lOn2+Qi+o']
    elsif Rails.env.development?
#      ['freshpo.com', 'mZ4Mvav/PzfC5X2lOn2+Qi+o']
      ['663183371165.apps.googleusercontent.com', 'Td7XaDzfHiNZzZChgmHjJUHy']
    end
  end

  # While exporting the db data into google, db will not contain correct google_id.  For this update_google_id will be useful. 
  def remove_discrepancy(db_contacts, google_contacts, precedence="LATEST", update_google_id=false)
    puts "BEFORE remove_discrepancy, total db contacts: #{db_contacts.length}, total google contacts: #{google_contacts.length}"
    google_contacts.each { |google_contact|
      db_contacts.each { |db_contact|
        if is_matched(google_contact, db_contact)
#          puts "Found a discrepancy. Db contact = #{db_contact.inspect} Google contact , #{google_contact.inspect}"
          if precedence == "LATEST"
            if google_contact.updated_at == db_contact.updated_at
              precedence = "BOTH"
            elsif db_contact.updated_at > google_contact.updated_at
              precedence = "DB"
            else
              precedence = "GOOGLE"
            end
          end
          if precedence == "DB"
            google_contacts.delete(google_contact)
          elsif precedence == "GOOGLE"
            db_contacts.delete(db_contact)
          elsif precedence == "BOTH"
            google_contacts.delete(google_contact)
            db_contacts.delete(db_contact)
          end
          db_contact.google_id = google_contact.id if db_contact.google_id.blank? or update_google_id
        end
      }
    }
    puts "AFTER remove_discrepancy, total db contacts: #{db_contacts.length}, total google contacts: #{google_contacts.length}"
  end

  def is_matched(google_contact, db_contact)
    google_contact.id == db_contact.google_id.to_s or google_contact.email == db_contact.email or google_contact.second_email == db_contact.email
  end


  def contact_xml(user, google_xml)
    sync_group_id = "abcdef"
    doc = REXML::Document.new("<feed xmlns='http://www.w3.org/2005/Atom' xmlns:openSearch='http://a9.com/-/spec/opensearchrss/1.0/' xmlns:gContact='http://schemas.google.com/contact/2008' xmlns:batch='http://schemas.google.com/gdata/batch' xmlns:gd='http://schemas.google.com/g/2005'>"+google_xml+"</feed>")
    contact_ele_xml = nil
    doc.elements.each('feed/entry') {|entry_element|
      #email
      entry_element.elements.each('gd:email') { |email_element|
        is_primary = email_element.attribute('primary').value
        rel = email_element.attribute('rel').value
        unless is_primary.blank? || is_primary != "true"
          entry_element.delete_element(email_element) unless user.email.blank?
        else
          entry_element.delete_element(email_element) if rel.end_with?("home") && !user.second_email.blank?
        end
      }

      # do not remove id
      # title
      id_elements = entry_element.get_elements('title')
      entry_element.delete_element(id_elements[0]) unless id_elements.blank? or user.name.blank?

      #deleted
      deleted_elements = entry_element.get_elements('gd:deleted')
      entry_element.delete_element(deleted_elements) unless deleted_elements.blank? or user.deleted

      #postalAddress
      entry_element.elements.each('gd:postalAddress') { |element|
        rel = element.attribute('rel').value
        if rel.end_with?("work")
          entry_element.delete_element(element) unless user.address.blank?
          break;
        end
      }

      #phoneNumber
      entry_element.elements.each('gd:phoneNumber') { |element|
        rel = element.attribute('rel').value
        value = element.text.strip
        if rel.end_with?("work")
          entry_element.delete_element(element) unless user.phone.blank?
        elsif rel.end_with?("mobile")
          entry_element.delete_element(element) unless user.mobile.blank?
        end
      }

      #orgName
      org_elements = entry_element.get_elements('gd:organization')
      entry_element.delete_element(org_elements) unless org_elements.blank? or user.customer.blank?

      #content
      content_elements = entry_element.get_elements('content')
      entry_element.delete_element(content_elements) unless content_elements.blank? or user.description.blank?

      # group
      entry_element.elements.each("gContact:groupMembershipInfo") {|element|
        group_id = Integrations::GoogleContactsUtil.parse_id([element.attribute('href').value])
        entry_element.delete_element(element) unless group_id.blank? or group_id != sync_group_id
      }

      entry_element.delete_element(entry_element.get_elements('updated')[0]) #updated

      # Add all the deleted elements now.
      user.class.column_names.collect { |prop_name|
        if(user.has_attribute?(prop_name) && @@fd_goog_contact_xml_mapping.has_key?(prop_name))
          prop_value = user.read_attribute(prop_name)
          unless prop_value.blank?
            goog_prop_xml = @@fd_goog_contact_xml_mapping[prop_name]
            prop_value = prop_value.to_s.to_xs
            entry_element.add_element(REXML::Element.new(goog_prop_xml.gsub("$"+prop_name, prop_value)))
          end
        end
      }
      entry_element.add_element(REXML::Element.new("<gd:organization rel='http://schemas.google.com/g/2005#other'><gd:orgName>#{company_name}</gd:orgName></gd:organization>")) unless group_uri.blank?
      entry_element.add_element(REXML::Element.new("<gContact:groupMembershipInfo deleted='false' href='#{group_uri}'/>")) unless group_uri.blank?
      contact_ele_xml = entry_element
    }
    contact_ele_xml.to_s
  end

  def parse_user_xml(entry_element)
    goog_contact_detail = {}
    goog_contact_detail[:google_xml] = entry_element.to_s #google_xml
    #email
    entry_element.elements.each('gd:email') { |email_element|
      is_primary = email_element.attribute('primary').value
      rel = email_element.attribute('rel').value
      unless is_primary.blank? || is_primary != "true"
        goog_contact_detail[:primary_email] = email_element.attribute('address').value
      else
        goog_contact_detail[:second_email] = email_element.attribute('address').value if rel.end_with?("home")
      end
    }

    goog_contact_detail[:google_id] = Integrations::GoogleContactsUtil.parse_id([entry_element.get_text('id').value]) #id
    goog_contact_detail[:title] = entry_element.get_text('title').value #title
    #deleted
    deleted_val = entry_element.get_elements('gd:deleted')
    if deleted_val.blank?
      goog_contact_detail[:deleted] = false
    else
      goog_contact_detail[:deleted] = true
    end
    #postalAddress
    entry_element.elements.each('gd:postalAddress') { |element|
      rel = element.attribute('rel').value
      value = element.text.strip
      if rel.end_with?("work")
        goog_contact_detail[:postalAddress_work] = value
      elsif rel.end_with?("home")
        goog_contact_detail[:postalAddress_home] = value
      end
    }
    #phoneNumber
    entry_element.elements.each('gd:phoneNumber') { |element|
      rel = element.attribute('rel').value
      value = element.text.strip
      if rel.end_with?("work")
        goog_contact_detail[:phoneNumber_work] = value
      elsif rel.end_with?("mobile")
        goog_contact_detail[:phoneNumber_mobile] = value
      end
    }
    #orgName
    goog_contact_detail[:orgName] = entry_element.get_text('gd:organization/gd:orgName').value
    goog_contact_detail[:content] = entry_element.get_text('content').value #content
    #google_group_ids
    google_group_ids = []
    entry_element.elements.each("gContact:groupMembershipInfo") {|element|
      group_id = Integrations::GoogleContactsUtil.parse_id([element.attribute('href').value])
      google_group_ids.push(group_id) unless group_id.blank?
    }
    goog_contact_detail[:google_group_ids] = google_group_ids
    goog_contact_detail[:updated_at] = Time.parse(entry_element.get_text('updated').value) #updated
    goog_contact_detail
  end

  def enable_integration(goog_acc)
    Integrations::Application.install(APP_NAMES[:google_contacts])
    goog_acc.save
  end
end
