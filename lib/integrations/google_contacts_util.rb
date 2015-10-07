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

  #Called during Freshdesk to Google case.
  #Converting User object to XML for API consumption.
  def trimmed_contact_xml(user, goog_cnt, sync_group_id=nil)
    google_xml = goog_cnt.google_xml
    return if google_xml.blank?
    doc = Nokogiri::XML("<feed xmlns='http://www.w3.org/2005/Atom' xmlns:openSearch='http://a9.com/-/spec/opensearchrss/1.0/' xmlns:gContact='http://schemas.google.com/contact/2008' xmlns:batch='http://schemas.google.com/gdata/batch' xmlns:gd='http://schemas.google.com/g/2005'>"+google_xml+"</feed>")

    entry_element = doc.at_css("feed entry")
  
    # remove id/category, this gets appended while constructing the full xml.
    entry_element.xpath('xmlns:id').remove
    entry_element.xpath('xmlns:category').remove

    # name
    entry_element.xpath('gd:name').remove if user.name.present?

    #email
    entry_element.xpath('gd:email').each do |email_element|
      is_primary = email_element.attribute('primary').value
      rel = email_element.attribute('rel').value

      if is_primary.present? && is_primary == "true"
        email_element.remove if user.email.present?
      else
        email_element.remove if rel.end_with?("home") && user.second_email.present?
      end
    end

    #phoneNumber
    entry_element.xpath('gd:phoneNumber').each do |element|
      rel = element.attribute("rel").value
      element.text.strip
      if rel.end_with?("work")
        element.remove if user.phone.present?
      elsif rel.end_with?("mobile")
        element.remove if user.mobile.present?
      end
    end

    #postalAddress
    entry_element.xpath('gd:structuredPostalAddress').each do |element| 
      rel = element.attribute('rel').value
      if rel.end_with?("work")
        element.remove if user.address.present?
      end
    end

    #content/description
    entry_element.xpath('xmlns:content').remove if user.description.present?

    #deleted
#      delete(entry_element, entry_element.get_elements('gd:deleted')) unless user.deleted

    #orgName
    entry_element.xpath('gd:organization').remove if user.company.present?

    # group
    entry_element.xpath('gContact:groupMembershipInfo').each do |element|
      group_id = self.sync_group_id
      element.remove if group_id.present? && group_id == sync_group_id
    end

    entry_element.xpath('xmlns:updated').remove
    entry_element
  end


  #Called during Google to Freshdesk case.
  #XML to Google Contact object conversion.
  def parse_user_xml(entry_element)
    goog_contact_detail = {}
    goog_contact_detail[:google_xml] = entry_element.to_s #google_xml
    #email
    entry_element.xpath('gd:email').each { |email_element|
      is_primary = email_element.attribute('primary').value
      rel = email_element.attribute('rel').value
      if is_primary.present? && is_primary == "true"
        goog_contact_detail[:primary_email] = email_element.attribute('address').value
      else
        addr = email_element.attribute('address').value
        goog_contact_detail[:second_email] = addr
        goog_contact_detail[:primary_email] = addr if goog_contact_detail[:primary_email].blank?
      end
    }
    goog_contact_detail[:second_email] = nil if goog_contact_detail[:second_email] == goog_contact_detail[:primary_email]

    goog_contact_detail[:google_id] = Integrations::GoogleContactsUtil.parse_id([entry_element.xpath("xmlns:id").text]) #id

    name_element = entry_element.xpath("gd:name/gd:fullName").first
    goog_contact_detail[:name] = name_element.present? ? name_element.text : nil #name

    #deleted
    goog_contact_detail[:deleted] = entry_element.xpath("gd:deleted").present?

    #postalAddress
    entry_element.xpath('gd:structuredPostalAddress').each do |element|
      formatted_addr_element = element.xpath("gd:formattedAddress").first
      rel = element.attribute('rel').value
      value = formatted_addr_element.text.strip
      if rel.end_with?("work")
        goog_contact_detail[:postalAddress_work] = value
      elsif goog_contact_detail[:postalAddress_work].blank?
        goog_contact_detail[:postalAddress_work] = value
      end
    end
    #phoneNumber
    entry_element.xpath('gd:phoneNumber').each { |element|
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
    org_name_element = entry_element.xpath('gd:organization/gd:orgName').first
    goog_contact_detail[:orgName] = org_name_element.present? ? org_name_element.text : nil

    #content
    content_element = entry_element.xpath('xmlns:content').first
    goog_contact_detail[:content] = content_element.present? ? content_element.text : nil

    goog_contact_detail[:google_group_ids] = self.sync_group_id

    #updated
    updated_element = entry_element.xpath('xmlns:updated').first
    goog_contact_detail[:updated_at] = updated_element.present? ? Time.parse(updated_element.text) : nil
    goog_contact_detail
  end

  def enable_integration(goog_acc)
    config_hash = construct_installed_app_config(goog_acc)
    Integrations::Application.install_or_update(APP_NAMES[:google_contacts], goog_acc.account, config_hash)
    goog_acc.save!
  end

  def remove_installed_app_config(google_acc_id)
    current_config = nil
    google_acc = current_account.google_accounts.find_by_id(google_acc_id)
    installed_app = current_account.installed_applications.with_name("google_contacts").first
    current_config = installed_app["configs"][:inputs] unless installed_app["configs"].blank?
    unless current_config.blank? || current_config["OAuth2"].blank?
      if current_config["OAuth2"].include?("#{google_acc.email}") #Redundant check, remove it in the next iteration.
        current_config["OAuth2"].delete("#{google_acc.email}") 
        installed_app.save
      end
    end
  end

  private
    def construct_installed_app_config goog_acc
      installed_app = goog_acc.account.installed_applications.with_name("google_contacts").first
      current_config = nil # Can do a compact & flatten and can make the initial assignment as {}
      current_config = installed_app["configs"][:inputs] unless installed_app["configs"].blank?
      unless current_config.blank? || current_config["OAuth2"].blank?
        current_config["OAuth2"] << "#{goog_acc.email}"
      else
        current_config = {}
        current_config["OAuth2"] = ["#{goog_acc.email}"]
      end
      current_config
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
