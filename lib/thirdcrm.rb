require 'capsulecrm'
require 'active_record'

include ErrorHandle

class ThirdCRM
  
  def initialize
    CapsuleCRM.account_name = AppConfig['crm'][RAILS_ENV]['domain']
    CapsuleCRM.api_token = AppConfig['crm'][RAILS_ENV]['api_key']
    CapsuleCRM.initialize!
  end  
  
  #Account name,helpdesk_url,creation_date,renewal_date,time_zone
  #Contact -> name,email
  def add_signup_data
    account = Account.first
    organisation_id = add_organisation(account)
    person_id = add_contact(account,organisation_id)
    add_tag("Sign Up",organisation_id)
  end
  
  def add_organisation(account)
    organisation = CapsuleCRM::Organisation.new
    organisation.name = "#{account.name}#{rand(1000)}"
    organisation_id = organisation.save
    puts organisation_id
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
  
  def add_signup_data
    
  end
  
  def add_customer_data
    
  end
  
  def update_subscription
    
  end
  
end