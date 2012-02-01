module Integrations::GoogleContactsUtil

  NilClass.class_eval do
    # define each method in the Nil class.  So that no need to check the blank every time before iterating.
    def each
    end

    def length
      return 0
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
#    puts "goog_id_uri #{goog_id_uri}"
    matched_goog_id = /\[*base\/(.*)/.match(goog_id_uri[0]) unless goog_id_uri.blank? # looking for pattern 'any chars/base/<id>'
    return matched_goog_id[1] unless matched_goog_id.blank?
  end

  # TODO See the feasibility of adding the below methods into some factory class.
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

  def is_db_latest(google_contact, db_contact)
    puts "############# google_contact #{google_contact.inspect}   db_contact #{db_contact.inspect} #################"
    false
  end

  def is_matched(google_contact, db_contact)
    google_contact.id == db_contact.google_id.to_s or google_contact.email == db_contact.email or google_contact.second_email == db_contact.email
  end
end
