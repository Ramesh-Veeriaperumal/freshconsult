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

    def google_contacts
    end
    def google_id
    end
    def google_xml
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
    matched_goog_id = /.*[base||full]\/(.*)/.match(goog_id_uri[0]) unless goog_id_uri.blank? # looking for pattern 'any chars/[base or full]/<id>'
    return matched_goog_id[1] unless matched_goog_id.blank?
  end


  def trimmed_contact_xml(user, goog_cnt, sync_group_id=nil)
    google_xml = goog_cnt.google_xml
    return if google_xml.blank?
    doc = REXML::Document.new("<feed xmlns='http://www.w3.org/2005/Atom' xmlns:openSearch='http://a9.com/-/spec/opensearchrss/1.0/' xmlns:gContact='http://schemas.google.com/contact/2008' xmlns:batch='http://schemas.google.com/gdata/batch' xmlns:gd='http://schemas.google.com/g/2005'>"+google_xml+"</feed>")
    contact_ele_xml = nil
    doc.elements.each('feed/entry') {|entry_element|
      # remove id/category, this gets appended while constructing the full xml.
      delete(entry_element, entry_element.get_elements('id'))
      delete(entry_element, entry_element.get_elements('category'))

      # name
      delete(entry_element, entry_element.get_elements('gd:name')) unless user.name.blank?

      #email
      entry_element.elements.each('gd:email') { |email_element|
        is_primary = email_element.attribute('primary').value
        rel = email_element.attribute('rel').value
        unless is_primary.blank? || is_primary != "true"
          delete(entry_element, email_element) unless user.email.blank?
        else
          delete(entry_element, email_element) if rel.end_with?("home") && !user.second_email.blank?
        end
      }

      #phoneNumber
      entry_element.elements.each('gd:phoneNumber') { |element|
        rel = element.attribute('rel').value
        value = element.text.strip
        if rel.end_with?("work")
          delete(entry_element, element) unless user.phone.blank?
        elsif rel.end_with?("mobile")
          delete(entry_element, element) unless user.mobile.blank?
        end
      }

      #postalAddress
      entry_element.elements.each('gd:structuredPostalAddress') { |element|
        rel = element.attribute('rel').value
        if rel.end_with?("work")
          delete(entry_element, element) unless user.address.blank?
        end
      }

      #content/description
      delete(entry_element, entry_element.get_elements('content')) unless user.description.blank?

      #deleted
#      delete(entry_element, entry_element.get_elements('gd:deleted')) unless user.deleted

      #orgName
      delete(entry_element, entry_element.get_elements('gd:organization')) unless user.company.blank?

      # group
      entry_element.elements.each("gContact:groupMembershipInfo") {|element|
        group_id = self.sync_group_id
        delete(entry_element,element) unless group_id.blank? or group_id != sync_group_id
      }

      delete(entry_element,entry_element.get_elements('updated')) #updated
      contact_ele_xml = entry_element
    }
    contact_ele_xml
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
        addr = email_element.attribute('address').value
        goog_contact_detail[:second_email] = addr
        goog_contact_detail[:primary_email] = addr if goog_contact_detail[:primary_email].blank?
      end
    }
    goog_contact_detail[:second_email] = nil if goog_contact_detail[:second_email] == goog_contact_detail[:primary_email]

    goog_contact_detail[:google_id] = Integrations::GoogleContactsUtil.parse_id([entry_element.get_text('id').value]) #id
    goog_contact_detail[:name] = entry_element.get_text('gd:name/gd:fullName').value #name
    #deleted
    deleted_val = entry_element.get_elements('gd:deleted')
    if deleted_val.blank?
      goog_contact_detail[:deleted] = false
    else
      goog_contact_detail[:deleted] = true
    end
    #postalAddress
    entry_element.elements.each('gd:structuredPostalAddress') { |element|
      formatted_addr_element = element.get_elements('gd:formattedAddress')[0]
      rel = element.attribute('rel').value
      value = formatted_addr_element.text.strip
      if rel.end_with?("work")
        goog_contact_detail[:postalAddress_work] = value
      elsif goog_contact_detail[:postalAddress_work].blank?
        goog_contact_detail[:postalAddress_work] = value
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
      elsif goog_contact_detail[:phoneNumber_work].blank?
        goog_contact_detail[:phoneNumber_work] = value 
      elsif goog_contact_detail[:phoneNumber_home].blank?
        goog_contact_detail[:phoneNumber_home] = value 
      end
    }
    #orgName
    goog_contact_detail[:orgName] = entry_element.get_text('gd:organization/gd:orgName').value
    goog_contact_detail[:content] = entry_element.get_text('content').value #content
    #google_group_ids
    google_group_ids = []
    entry_element.elements.each("gContact:groupMembershipInfo") {|element|
      group_id = self.sync_group_id
      google_group_ids.push(group_id) unless group_id.blank?
    }
    goog_contact_detail[:google_group_ids] = self.sync_group_id
    goog_contact_detail[:updated_at] = Time.parse(entry_element.get_text('updated').value) #updated
    goog_contact_detail
  end

  def enable_integration(goog_acc)
    Integrations::Application.install_or_update(APP_NAMES[:google_contacts], goog_acc.account)
    goog_acc.save!
  end

  private
    def delete(entry_element, delete_element)
      unless delete_element.blank?
        if delete_element.instance_of?(Array)
          entry_element.delete_element(delete_element[0])
        else
          entry_element.delete_element(delete_element)
        end
      end
    end

    def copy(from_user, to_user)
      USER_FIELDS.each { |prop_name|
        if(from_user.has_attribute?(prop_name))
          prop_value = from_user.read_attribute(prop_name)
          unless prop_value.blank?
            to_user.send(:write_attribute,prop_name, prop_value)
          end
        end
      }
      to_user.customer = from_user.customer
    end

    def fetch_current_account_contact(db_cnt, google_account)
      db_cnt.google_contacts.each {|g_cnt|
        return g_cnt if g_cnt.google_account_id == google_account.id
      }
      return nil
    end

=begin
    def correct_postal_address(entry_element, paddr_element)
      paddr_element.name = "gd:structuredPostalAddress"
      addr_val = paddr_element.text
      paddr_element.text = nil
      faEle = REXML::Element.new("gd:formattedAddress")
      faEle.text=addr_val
      paddr_element.add_element(faEle)
      paddr_element
    end
=end

    GOOGLE_USER_FIELD_XML_MAPPING = [
      [:name, "name", "<gd:name><gd:fullName>$name</gd:fullName></gd:name>"], 
      [:primary_email, "email", "<gd:email rel='http://schemas.google.com/g/2005#work' primary='true' address='$email'/>"], 
      [:second_email, "second_email", "<gd:email rel='http://schemas.google.com/g/2005#home' address='$second_email'/>"], 
      [:phoneNumber_mobile, "mobile", "<gd:phoneNumber rel='http://schemas.google.com/g/2005#mobile'>$mobile</gd:phoneNumber>"], 
      [:phoneNumber_work, "phone", "<gd:phoneNumber rel='http://schemas.google.com/g/2005#work' primary='true'>$phone</gd:phoneNumber>"], 
      [:postalAddress_work, "address", "<gd:structuredPostalAddress rel='http://schemas.google.com/g/2005#work' primary='true'> <gd:formattedAddress> $address </gd:formattedAddress> </gd:structuredPostalAddress>"], 
      [:content, "description", "<content>$description</content>"], 
      [:deleted, "deleted", nil], 
      [:updated_at, "updated_at", nil]
    ]
  
    USER_FIELDS = GOOGLE_USER_FIELD_XML_MAPPING.map { |i|  i[1] }.flatten
    GOOGLE_FIELDS_TO_USER_FILEDS_MAPPING = Hash[*GOOGLE_USER_FIELD_XML_MAPPING.map { |i| [i[0], i[1]] }.flatten]
    USER_FILEDS_TO_GOOGLE_XML_MAPPING = Hash[*GOOGLE_USER_FIELD_XML_MAPPING.map { |i| [i[1], i[2]] }.flatten]
end
