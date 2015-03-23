class PartnerAdmin::AffiliatesController < ApplicationController

  prepend_before_filter :check_admin_subdomain  
  skip_before_filter  :check_privilege, :set_time_zone, :set_current_account, :set_locale,
                      :check_account_state, :ensure_proper_protocol, :check_day_pass_usage,
                      :redirect_to_mobile_url, :determine_pod

  skip_filter :select_shard # as select shard is around filter need to skip both                      
  
  around_filter :select_account_shard, :only => :add_affiliate_transaction
  before_filter :authenticate_using_basic_auth, :ensure_right_parameters, :fetch_account, 
                :only => :add_affiliate_transaction
  
  #Reseller portal verifications
  before_filter :verify_timestamp, :verify_signature, :ssl_check, :authenticate_using_basic_auth,
                 :except => :add_affiliate_transaction  
  
  SUBSCRIPTION = { :account_id => :account_id, :helpdesk_name => :account_name, 
                    :domain => :account_full_domain, :admin_name => :admin_first_name, 
                    :email => :admin_email, :phone => :admin_phone ,:cmrr => :cmrr, 
                    :state => :state, :created_at => :created_at }

  STATES = [ "active", "free", "trial", "suspended" ]

  RECORDS_PER_PAGE = 30
  TIME_ALLOWED = 1800

  #Shareasale methods
  def select_account_shard(&block)
    Sharding.select_shard_of(params[:tracking]) do 
      yield 
    end
  end

  def add_affiliate_transaction
  	unless params[:amount].to_f > 0
      SubscriptionAffiliate.add_affiliate(@account,params[:userID]) 
  	end
    respond_to do |format|
    	format.xml  { head 200 }
    end
  end

  #Reseller portal API methods
  def add_reseller
    params = ActiveSupport::JSON.decode request.body.read
    affilate = SubscriptionAffiliate.new(params)
    
    if affilate.save
      render :json => { :success => true }
    else
      render :json => { :success => false, :errors => affilate.errors }
    end
  end

  def affiliate_subscription_summary
    params = decode_params(request)
    affiliate = SubscriptionAffiliate.find_by_token(params["token"])    
    summary = affiliate.nil? ? [] : subscription_summary(affiliate)
    render_json_object(summary)
  end

  def fetch_affilate_subscriptions
    params = decode_params(request)
    affiliate = SubscriptionAffiliate.find_by_token(params["token"])
    accounts = affiliate.nil? ? [] :
            subscription_details(affiliate, params["state"], params["page"])
    render_json_object(accounts)
  end

  def fetch_account_activity
    params = decode_params(request)
    activity = activity_info(params["id"])
    render_json_object(activity)
  end

  def add_subscriptions_to_reseller
    params = ActiveSupport::JSON.decode request.body.read
    associate_subscription(params["token"], params["domains"])
  end

  def fetch_reseller_account_info
    params = decode_params(request)
    info = {}
    Sharding.select_shard_of(params["account_id"]) do
      Sharding.run_on_slave do
        account = Account.find_by_id(params["account_id"])
        info = account ? account_info(account) : {}
      end
    end
    render_json_object(info)
  end

  def remove_reseller_subscription
    params = ActiveSupport::JSON.decode request.body.read    
    Sharding.select_shard_of(params["account_id"]) do
      subscription = Subscription.find_by_account_id(params["account_id"])
      subscription.account.make_current
      subscription.update_attributes(:subscription_affiliate_id => nil)
    end
    render_json_object({:success => true})
  end

  protected
    def ensure_right_parameters
      if ((!request.ssl?) or
        (!request.post?) or 
        (params[:tracking].blank?) or 
        (params[:userID].blank?) or 
        (params[:commission].blank?) or
        (params[:transID].blank?) or
        (params[:amount].blank?))
        return render :xml => ArgumentError, :status => 500
   	  end
    end

    def ensure_right_affiliate
     unless SubscriptionAffiliate.subscription_from_shareasale?(@account,params[:userID])   
      return render :xml => ActiveRecord::RecordNotFound, :status => 404 
     end
    end
    
    def fetch_account
      @account = Account.find_by_full_domain(params[:tracking])
      return render :xml => ActiveRecord::RecordNotFound, :status => 404 unless @account
    end

    def check_admin_subdomain
      raise ActionController::RoutingError, "Not Found" unless partner_subdomain?
    end
      
    def partner_subdomain?
      request.subdomains.first == AppConfig['partner_subdomain']
    end

    #Reseller API checks
    def verify_timestamp
      time_in_utc = Time.now.getutc.to_i
      if params[:timestamp].blank? or 
        !params[:timestamp].to_i.between?((time_in_utc - TIME_ALLOWED), time_in_utc)
        render :json => { :status => 401 }
      end
    end

    def verify_signature        
      digest  = OpenSSL::Digest.new('MD5')
      generated_hash = OpenSSL::HMAC.hexdigest(digest, portal_credentials[:shared_secret], 
                                        portal_credentials[:user_name]+params[:timestamp])
      unless params[:hash] == generated_hash
        render :json => { :status => 401 }
      end
    end

    def ssl_check
      render :json => ArgumentError, :status => 500 if (Rails.env.production? and !request.ssl?)
    end

    def authenticate_using_basic_auth
      authenticate_or_request_with_http_basic do |username, password|
        username == portal_credentials[:user_name] && password == portal_credentials[:password]
      end
    end

  private
    def decode_params(request)
      info = Base64.decode64 request.body.read
      params = ActiveSupport::JSON.decode info    
    end

    def render_json_object(object)
      object.empty? ? (render :json => { :success => false })  : 
                  (render :json => { :success => true, :data => object.to_json })
    end

    def subscription_summary(affiliate)
      summary = { :cmrr => reseller_cmrr(affiliate) }
      STATES.each do |state|
        summary[state] = affiliate_accounts(affiliate, state).count
      end      
      summary
    end

    def associate_subscription(reseller_token, domains)
      affiliate = SubscriptionAffiliate.find_by_token(reseller_token)      
      render :json => { :success => false } if affiliate.nil?

      mapped_accounts = []
      unmapped_accounts = []
      domains.each do |domain|
        domain_mapping = DomainMapping.find_by_domain(domain)
        if domain_mapping
          Sharding.select_shard_of(domain) do 
            account = Account.find_by_full_domain(domain)
            SubscriptionAffiliate.add_affiliate(account, affiliate.token)
            mapped_accounts << account_info(account)
          end
        else          
          unmapped_accounts << domain
        end
      end
      
      render :json => { :success => true, :mapped_accounts => mapped_accounts, 
                        :unmapped_accounts => unmapped_accounts }
    end

    #To be moved to ChargeBee. Temporarily fetching affiliate accounts with state & page.
    def subscription_details(affiliate, state, page)
      accounts = affiliate_accounts(affiliate, state)
      start_index = RECORDS_PER_PAGE * (page.to_i - 1)
      end_index = start_index + RECORDS_PER_PAGE - 1
      return [] if accounts.empty? or accounts.count < start_index

      accounts[start_index..end_index].collect do |subscription|
        Sharding.select_shard_of(subscription.account_id) do
          SUBSCRIPTION.inject({}) { |h, (k, v)| h[k] = subscription.send(v); h }
        end
      end
    end

    def reseller_cmrr(affiliate)
      active_accounts = affiliate_accounts(affiliate, "active")
      active_accounts.inject(0) { |sum, subscription| sum + subscription.cmrr }
    end

    def affiliate_accounts(affiliate, state)
      accounts = []
      accounts = Sharding.run_on_all_slaves do
        affiliate.subscriptions.filter_with_state(state).find(:all)
      end
      accounts.flatten.uniq{|x| x.account_id}
    end

    def activity_info(account_id)
      Sharding.select_shard_of(account_id) do 
        Sharding.run_on_slave do
          account = Account.find_by_id(account_id)
          account.nil? ? {} : 
          {
            :tickets_count => account.tickets.count,
            :twitter => !account.twitter_handles.blank?,
            :facebook => !account.facebook_pages.blank?, 
            :emails_configured => account.all_email_configs.count,
            :agent_count => account.full_time_agents.count,
            :portal_count => account.portals.count,
            :chat => account.features?(:chat)
          }
        end
      end
    end

    def account_info(account)
      {
        :account_id => account.id,        
        :name => account.name,
        :domain => account.full_domain,
        :email => account.admin_email,
        :phone => account.admin_phone,
        :created_at => account.created_at,
        :state => account.subscription.state,
        :cmrr => account.subscription.amount/account.subscription.renewal_period,
        :conversion_metric => account.conversion_metric ? account.conversion_metric.session_json : {},
        :currency => account.currency_name,
        :first_name => account.admin_first_name,
        :last_name => account.admin_last_name
      }
    end

    def portal_credentials
      {
        :user_name => AppConfig["reseller_portal"]["user_name"],
        :password => Digest::MD5.hexdigest(AppConfig["reseller_portal"]["password"]),
        :shared_secret => AppConfig["reseller_portal"]["shared_secret"]
      }
    end 

end