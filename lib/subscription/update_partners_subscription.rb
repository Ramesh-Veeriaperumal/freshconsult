class Subscription::UpdatePartnersSubscription
  include Sidekiq::Worker

  sidekiq_options :queue => :partners_event_queue, :retry => 0, :failures => :exhausted

  USER_AGENT = "Freshdesk"
  REQUEST_URL = AppConfig["reseller_portal"]["portal_url"][Rails.env]
  REQUEST_ACTION = "update_reseller_subscription"
  AUTH_PARAMS = {
    :user_name => AppConfig["reseller_portal"]["user_name"],
    :password => AppConfig["reseller_portal"]["password"],
    :shared_secret => AppConfig["reseller_portal"]["shared_secret"]
  }

  def perform(args)
    begin
      account = Account.current
      return if account.subscription.affiliate.nil? 
      safe_send(%(trigger_#{args['event_type']}_event), account, args)
    rescue Exception => e
      logger.info "#{e}"
      logger.info e.backtrace.join("\n")
      logger.info "something is wrong: #{e.message}"
      NewRelic::Agent.notice_error(e)   
      raise e 
    end
  end

  private
    def trigger_subscription_updated_event(account, args)
      data = { :account_id => account.id, :state => account.subscription.state, 
                :cmrr => (account.subscription.amount/account.subscription.renewal_period), 
                :currency => account.currency_name, :next_renewal_at => account.subscription.next_renewal_at, :product_name => USER_AGENT}        
      http_connect(:subscription_updated, data, "post")
    end

    def trigger_contact_updated_event(account, args)
      data = { :account_id => account.id, :email => account.admin_email, :phone => account.admin_phone, :product_name => USER_AGENT}
      http_connect(:contact_updated, data, "post")
    end 

    def trigger_payment_added_event(account, args)
      data = { :account_id => account.id, :invoice_id => args["invoice_id"], :product_name => USER_AGENT}
      http_connect(:payment_added, data, "post")
    end

    def trigger_auto_collection_off_event(account, args = {})
      data = {:account_id => account.id, :product_name => USER_AGENT}
      http_connect(:auto_collection_turned_off, data, "post")
    end

    def trigger_domain_updated_event(account, args = {})
      data = {:domain => account.full_domain, :product_name => USER_AGENT, :account_id => account.id}
      http_connect(:domain_updated, data, "post")
    end

    def http_connect(event_type, data, req_type)        
      hrp = HttpRequestProxy.new
      req_params = { :user_agent => USER_AGENT, :auth_header => auth_header }
      body = { :event_type => event_type, :content => data }
      params = build_request_params(req_type, body)        
      fields_meta_data = hrp.fetch_using_req_params(params, req_params)
    end

    def build_request_params(req_type, body)
      {
        :domain => REQUEST_URL, 
        :rest_url => build_rest_url(REQUEST_ACTION),
        :method => req_type, 
        :ssl_enabled => "false", 
        :content_type => "application/json", 
        :body => body.to_json 
      }
    end

    def auth_header
      "Basic #{Base64.encode64(%(#{AUTH_PARAMS[:user_name]}:#{AUTH_PARAMS[:password]}))}"
    end

    def build_rest_url(action)
      timestamp = Time.now.getutc.to_i.to_s
      digest  = OpenSSL::Digest.new('MD5')
      user_name = AUTH_PARAMS[:user_name]
      shared_secret = AUTH_PARAMS[:shared_secret]
      
      hash = OpenSSL::HMAC.hexdigest(digest, shared_secret, user_name+timestamp)
      query_string = "/?timestamp=" + timestamp + "&hash=" + hash
      action + query_string
    end

end
