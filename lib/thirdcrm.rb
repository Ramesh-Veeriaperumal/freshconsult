require 'capsulecrm'
require 'active_record'

include ErrorHandle

class ThirdCRM
  
  SIGNUP_DATA = [{:label => "Account Creation Date", :method => "created_at", :data_type => "date"},
                 {:label => "Account Renewal Date", :method => "subscription_next_renewal_at", :data_type => "date"},
                 {:label => "Helpdesk URL", :method => "full_domain", :data_type => "text"}]
  
  def initialize
    CapsuleCRM.account_name = AppConfig['crm'][RAILS_ENV]['domain']
    CapsuleCRM.api_token = AppConfig['crm'][RAILS_ENV]['api_key']
    CapsuleCRM.initialize!
  end  
  
  #Account name,helpdesk_url,creation_date,renewal_date,time_zone
  #Contact -> name,email
  def add_signup_data(account)
    organisation_id = add_organisation(account)
    person_id = add_contact(account,organisation_id)
    add_tag("Sign Up",organisation_id)
    custom_fields = construct_custom_field_data(SIGNUP_DATA,"Sign Up",account)
    create_custom_fields(custom_fields,organisation_id)
  end
  
  def create_custom_fields(custom_fields,organisation_id)
    return false if custom_fields.empty?
    path = "/api/party/#{organisation_id}/customfields"
    options = {:root => 'customFields', :path => path}
    xml_out = ""
    custom_fields.each do |field|
      xml_out += field.attributes_hash.to_xml(:skip_instruct => true,:root => 'customField')
    end
    xml_new =  "<?xml version=\"1.0\" encoding=\"UTF-8\"?><customFields>"+xml_out+"</customFields>"
    CapsuleCRM::Base.create xml_new, options
  end
  
  def construct_custom_field_data(data,tag_name,account)
    custom_fields = []
    data.each do |val_hash|
      custom_field = CapsuleCRM::CustomField.new
      custom_field.label = val_hash[:label]
      custom_field.tag = tag_name
      custom_field.send("#{val_hash[:data_type]}=", account.send(val_hash[:method]))
      custom_fields.push(custom_field)
    end
    custom_fields
  end
  
  def add_organisation(account)
    organisation = CapsuleCRM::Organisation.new
    organisation.name = account.name
    organisation_id = organisation.save
    puts organisation_id
    raise Exception if organisation_id.blank?
    organisation_id
  end
  
  def add_contact(account,organisation_id)
    person = CapsuleCRM::Person.new
    account_admin = account.account_admin
    person.name = account_admin.name
    person.email = account_admin.email
    person.organisation_id = organisation_id
    person_id = person.save
    raise Exception if person_id.blank?
    person_id
  end
  
  def add_tag(tag_name,organisation_id)
    tag = CapsuleCRM::Tag.new
    tag.name = tag_name
    tag.party_id = organisation_id
    tag.save
  end
  
  def add_customer_data
    
  end
  
  def update_subscription
    
  end
  
end