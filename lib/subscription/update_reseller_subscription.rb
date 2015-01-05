class Subscription::UpdateResellerSubscription
  extend Resque::AroundPerform

  @queue = "events_queue"

  USER_AGENT = "Freshdesk"
  REQUEST_URL = AppConfig["reseller_portal"]["portal_url"][Rails.env]
  REQUEST_ACTION = "update_reseller_subscription"
  AUTH_PARAMS = {
    :user_name => AppConfig["reseller_portal"]["user_name"],
    :password => AppConfig["reseller_portal"]["password"],
    :shared_secret => AppConfig["reseller_portal"]["shared_secret"]
  }

  class << self

    def perform(args)
      account = Account.current
      return if account.subscription.affiliate.nil?
      
      send(%(trigger_#{args[:event_type]}_event), account, args)
    end

    private
      def trigger_subscription_updated_event(account, args)
        data = { :account_id => account.id, :state => account.subscription.state, 
                  :cmrr => (account.subscription.amount/account.subscription.renewal_period), 
                  :currency => account.currency_name }        
        http_connect(:subscription_updated, data, "post")
      end

      def trigger_contact_updated_event(account, args)
        data = { :account_id => account.id, :email => account.admin_email, :phone => account.admin_phone }
        http_connect(:contact_updated, data, "post")
      end 

      def trigger_payment_added_event(account, args)
        data = { :account_id => account.id, :invoice_id => args[:invoice_id] }
        http_connect(:payment_added, data, "post")
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

end