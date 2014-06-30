class ThirdCRM

  COOKIE_NAME = "_mkto_trk"

  API_KEYS = AppConfig['marketo'][Rails.env]
  PRODUCT_NAME = "Freshdesk"
  
  def initialize
    @client = Marketo::Client.new_marketo_client(
      API_KEYS['access_key'], API_KEYS['secret_key'], API_KEYS['api_subdomain'], API_KEYS['api_version'] )
  end  

  def self.fetch_cookie_info(cookies)
    begin
      cookies.fetch(COOKIE_NAME, "")
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
    end
  end

  def add_signup_data(account, options = {})
    @signup_id = options[:signup_id]
    add_lead_to_crm(lead_info(account), options[:marketo_cookie])
  end

  def lead_info(account)
    account_info = user_info(account)
    subscription_info = subscription_info(account.subscription)
    misc = account.conversion_metric ? signup_info(account.conversion_metric) : {}
    
    account_info.merge(subscription_info).merge(misc)
  end


  private
    def client
      @client 
    end

    def add_lead_to_crm(lead_record, marketo_cookie)
      client.sync_lead(lead_record[:Email], marketo_cookie, lead_record)
    end

    def user_info(account)
      LEAD_INFO.inject({}) { |h, (k, v)| h[k] = account.send(v); h } 
    end


    def subscription_info(subscription)
      {
        :Customer_Status__c => subscription.state,
        :Customer_Status__c_contact => subscription.state,
        :Account_Created_Date__c => subscription.created_at.to_s(:db),
        :Account_Renewal_Date__c => subscription.next_renewal_at.to_s(:db),
        :Product__c => PRODUCT_NAME
      }
    end

    def signup_info(metrics)
      {
        :Country => metrics.country,
        :Signup_source__c => metrics.landing_url ? tld(metrics.landing_url) : DEFAULT_DOMAIN,
        :Signup_Referrer => metrics.landing_url,
        :freshdesk_referrer => metrics.referrer,
        :freshdesk_first_referrer => metrics.first_referrer,
        :signup_referrer__c => metrics.landing_url,
        :freshdesk_referrer__c => metrics.referrer,
        :freshdesk_first_referrer__c => metrics.first_referrer,
        :Signup_ID => @signup_id
      }
    end

    def tld(landing_url)
      TOP_LEVEL_DOMAINS[TLDOMAINS.select { |tld| landing_url.include?(tld) }.to_s]
    end
    

    LEAD_INFO = { :LastName => :admin_first_name, :FirstName => :admin_last_name,
                  :Email => :admin_email, :Phone => :admin_phone, :Company => :name,
                  :Freshdesk_Account_Id__c => :id, :Freshdesk_Domain_Name__c => :full_domain }       

    TOP_LEVEL_DOMAINS = {
      "freshdesk.com.br" => "freshdesk_brazil",
      "freshdesk.de" => "freshdesk_germany",
      "freshdesk.es" => "freshdesk_spain",
      "freshdesk.fr" => "freshdesk_france",
      "freshdesk.it" => "freshdesk_italy",
      "freshdesk.nl" => "freshdesk_netherlands",
      "freshdesk.co.za" => "freshdesk_southafrica"
    }


    TLDOMAINS = TOP_LEVEL_DOMAINS.map{ |tld, id| tld }
    DEFAULT_DOMAIN = "freshdesk"

end