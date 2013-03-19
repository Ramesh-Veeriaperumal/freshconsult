class ThirdCRM

  COOKIE_NAME = "_mkto_trk"
  
  def initialize
    access_key = AppConfig['marketo'][RAILS_ENV]['access_key']
    secret_key = AppConfig['marketo'][RAILS_ENV]['secret_key']
    api_subdomain = AppConfig['marketo'][RAILS_ENV]['api_subdomain']
    api_version = AppConfig['marketo'][RAILS_ENV]['api_version']
    
    @client = Marketo::Client.new_marketo_client(access_key, secret_key, api_subdomain, api_version)
  end  

  def client
    @client 
  end

  def self.fetch_cookie_info(cookies)
    begin
      cookies.fetch(COOKIE_NAME, "")
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
    end
  end

  def add_signup_data(account, options = {})
   #returned_val = sandbox(0) {
     lead_contact = add_contact(account)
     lead_custom_field = add_custom_field_data(account)
     lead_record = lead_contact.merge(lead_custom_field)
     marketo_cookie = options[:marketo_cookie]
     marketo_lead = contact_crm_api(lead_record, marketo_cookie)
   #}
    
    #If some error occours while dumping the data into 
    # if returned_val == 0
    #   FreshdeskErrorsMailer.deliver_error_in_crm!(account)
    # end
  end

  def add_contact(account)
    lead_contact = {}
    lead_contact[:FirstName] = account.admin_first_name
    lead_contact[:LastName] = account.admin_last_name    
    lead_contact[:Phone] = account.admin_phone
    lead_contact[:Email] = account.admin_email
    lead_contact[:Company ] = account.name
    lead_contact[:Country] = account.conversion_metric.country if account.conversion_metric
    lead_contact
  end

  def add_custom_field_data(account)
    subscription = account.subscription
    lead_custom_field = {}
    lead_custom_field[:Freshdesk_Account_Id__c] = account.id
    lead_custom_field[:Account_Created_Date__c ] = account.created_at.to_s(:db) 
    lead_custom_field[:Account_Renewal_Date__c] = subscription.next_renewal_at.to_s(:db) 
    lead_custom_field[:Freshdesk_Domain_Name__c ] = account.full_domain  
    lead_custom_field[:Plan__c ] = subscription.subscription_plan.name 
    lead_custom_field[:Amount__c] = subscription.amount 
    lead_custom_field[:Customer_Status__c] = subscription.state
    lead_custom_field[:Customer_Status__c_contact] = subscription.state
    lead_custom_field
  end
  
  def contact_crm_api(lead_record, marketo_cookie)
    # if !marketo_cookie.blank? and (client.get_lead_by_cookie(marketo_cookie))
    #   marketo_cookie = ""
    # end
    client.sync_lead(lead_record[:Email], marketo_cookie, lead_record)
  end
  
  def sandbox(return_value = nil)
      begin
        return_value = yield
      rescue Errno::ECONNRESET => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Connection reset Error!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Timeout::Error => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Timeout Error!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue EOFError => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "EOF error"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Errno::ETIMEDOUT => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "ETimedOut Error!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue OpenSSL::SSL::SSLError => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "SSL Error!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue SystemStackError => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "System stack error!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
        RAILS_DEFAULT_LOGGER.debug "Unexpected Exception!"
        RAILS_DEFAULT_LOGGER.debug e.to_s
      rescue 
        RAILS_DEFAULT_LOGGER.debug "Fatal Error!"
      end
      
      return return_value
      
    end
  
  
end