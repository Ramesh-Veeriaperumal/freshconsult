class PartnerAdmin::AffiliatesController < ApplicationController
  require 'base64'

  skip_before_filter :select_shard
	#prepend_before_filter :check_admin_subdomain
  skip_before_filter :check_privilege
  skip_before_filter :set_time_zone
  skip_before_filter :set_current_account
  skip_before_filter :set_locale
  skip_before_filter :check_account_state
  skip_before_filter :ensure_proper_protocol
  skip_before_filter :check_day_pass_usage
  skip_before_filter :redirect_to_mobile_url
  before_filter :authenticate_using_basic_auth, :except => [:add_affiliate_transaction]
  before_filter :ensure_right_parameters, :only => [:add_affiliate_transaction]
  before_filter :fetch_account, :only => [:add_affiliate_transaction]
  before_filter :ensure_right_affiliate, :only => [:add_affiliate_transaction]

  COMPONENTS = [:customers,:revenue]
  SUBSCRIPTION = {  :id => :id,
                    :amount => :cmrr ,:created_at => :created_at ,
                    :next_renewal_at => :next_renewal_at, :state => :state,
                    :helpdesk_name => :account_name, :full_domain => :account_full_domain,
                    :account_id => :account_id

                  }
TRANSACTION_DETAILS = { :account_id => :subscription_id,
                        :paid_on => :paid_on,
                        :start_date => :start_date,
                        :end_date => :end_date,
                        :amount => :amount    
                      }
  def add_affiliate_transaction 
  	unless params[:amount].to_f > 0
  	 SubscriptionAffiliate.add_affiliate(@account,params[:userID]) 
  	end
  	respond_to do |format|
    	format.xml  { head 200 }
	 end
  end

  def add_reseller
    params = ActiveSupport::JSON.decode request.body.read
    @object = SubscriptionAffiliate.create!(params)
    if @object.save
      render :json => {:success => true}
    else
      render :json => {:success => false, :errors => @object.errors}
    end
  end

  def subscription_account
    params = request.body.read
    info = Base64.decode64(params)
    params = ActiveSupport::JSON.decode info
    affiliate = SubscriptionAffiliate.find_by_token(params['token'])
    accounts = affiliate.nil? ? [] : subscription_details(affiliate)
    render_json_object(accounts)
  end


  def account_details
    params = request.body.read
    info = Base64.decode64(params)
    params = ActiveSupport::JSON.decode info
    account_info = Billing::Subscription.new.retrieve_subscription(params['account_id'])
    details = {}
    details[:customer] = account_info.customer
    details[:subscription] = account_info.subscription
    render_json_object(details)
  end   

  def reseller_summary
    params = ActiveSupport::JSON.decode Base64.decode64 request.body.read
    affiliate = SubscriptionAffiliate.find_by_token(params['token'])
    summary = COMPONENTS.inject({}) {|h,v| h[v] = {}; h}
    customers_type(affiliate).first.each do |key,value|
      summary[:customers][key.to_sym] = value
    end
    summary[:revenue][:cmrr] = 0
    Sharding.run_on_all_shards do
      affiliate.subscriptions.each do |n|
        summary[:revenue][:cmrr] +=  (n.amount/(n.renewal_period)).round(4) 
      end
    end
    render_json_object(summary)
  end

  def reseller_account_transaction
    params =  ActiveSupport::JSON.decode Base64.decode64 request.body.read
    affiliate = SubscriptionAffiliate.find_by_token(params['token'])
    subscriptions = subscription_details(affiliate)
    payment_data = subscriptions.collect{ |subscription| Billing::Subscription.new.retrieve_payments(subscription[:account_id]) }
    payment_details = payment_data.collect{ |subscription|  subscription_transaction(subscription) }
    render_json_object(payment_details)
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
   unless SubscriptionAffiliate.check_affiliate_in_metrics?(@account,params[:userID])   
    return render :xml => ActiveRecord::RecordNotFound, :status => 404 
   end
  end
  
  def fetch_account
    domain = DomainMapping.find_by_domain(params[:tracking])
    @account = Sharding.select_shard_of(domain.account_id) {Account.find_by_full_domain(params[:tracking])}
    return render :xml => ActiveRecord::RecordNotFound, :status => 404 unless @account
  end

  def check_admin_subdomain
    raise ActionController::RoutingError, "Not Found" unless partner_subdomain?
  end
    
  def partner_subdomain?
    request.subdomains.first == AppConfig['partner_subdomain']
  end

  def render_json_object(object)
    object.empty? ? (render :json => {:success => false})  : (render :json => {:success => true, :data => object.to_json })
  end
  
  def authenticate_using_basic_auth
    authenticate_or_request_with_http_basic do |username, password|
      username == 'freshdesk' && password == "098f6bcd4621d373cade4e832627b4f6"
    end
  end

  def subscription_transaction(subscription)
    subscription.collect{|data| TRANSACTION_DETAILS.inject({}) {|h,(k,v)| h[k] = data.invoice.send(v); h }}
  end

  def subscription_details(affiliate)
    Sharding.run_on_all_shards do
      affiliate.subscriptions.collect { |subscription| SUBSCRIPTION.inject({}) { |h, (k, v)| h[k] = subscription.send(v); h }}
    end
  end
  def customers_type(affiliate)
    Sharding.run_on_all_shards do
      affiliate.subscriptions.count(:all,:group => :state)
    end
  end
end