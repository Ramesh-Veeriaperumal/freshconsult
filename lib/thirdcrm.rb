require 'capsulecrm'
require 'active_record'

class ThirdCRM
  
  def initialize
    CapsuleCRM.account_name = AppConfig['crm'][RAILS_ENV]['domain']
    CapsuleCRM.api_token = AppConfig['crm'][RAILS_ENV]['api_key']
    CapsuleCRM.initialize!
  end
  
  def contact_capsule
    #person = CapsuleCRM::Person.find_by_email 'kiran@freshdesk.com'
    #person
    partys = CapsuleCRM::Organisation.find :all
    partys
  end
  
  #Account name,helpdesk_url,creation_date,renewal_date,time_zone
  #Contact -> name,email
  def add_signup_data
    
  end
  
  def add_customer_data
    
  end
  
  def update_subscription
    
  end
  
end