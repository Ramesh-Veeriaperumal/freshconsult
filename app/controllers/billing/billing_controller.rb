class Billing::BillingController < ApplicationController
  
  skip_before_filter :check_privilege, :verify_authenticity_token
  before_filter :login_from_basic_auth, :ssl_check

  skip_before_filter :set_current_account, :set_time_zone, :set_locale, 
                      :check_account_state, :ensure_proper_protocol,
                      :check_day_pass_usage, :redirect_to_mobile_url

  before_filter :ensure_right_parameters, :retrieve_account, 
                :load_subscription_info, :if => :monitored_event_not_from_api?
 
  
  EVENTS = [ "subscription_changed", "subscription_activated", "subscription_renewed", 
              "subscription_cancelled", "subscription_reactivated", "card_added", 
              "card_updated", "payment_succeeded", "payment_refunded", "card_deleted" ]          

  LIVE_CHAT_EVENTS = [ "subscription_activated", "subscription_renewed", "subscription_cancelled", 
                        "subscription_reactivated"]

  # Events to be synced for all sources including API.
  SYNC_EVENTS_ALL_SOURCE = [ "payment_succeeded", "payment_refunded", "subscription_reactivated" ]

  ADDONS_TO_IGNORE = ["bank_charges_monthly", "bank_charges_quarterly", "bank_charges_half_yearly", 
    "bank_charges_annual"]

  INVOICE_TYPES = { 
    :recurring => "0", 
    :non_recurring => "1" 
  }

  EVENT_SOURCES = {
    :api => "api"
  }

  META_INFO = { :plan => :subscription_plan_id, :renewal_period => :renewal_period, 
                :agents => :agent_limit, :free_agents => :free_agents }

  ADDRESS_INFO = { :first_name => :first_name, :last_name => :last_name, :address1 => :billing_addr1,
                    :address2 => :billing_addr2, :city => :billing_city, :state => :billing_state,
                    :country => :billing_country, :zip => :billing_zip  }

  IN_TRIAL = "in_trial"
  CANCELLED = "cancelled"
  NO_CARD = "no_card"
  OFFLINE = "off"

  TRIAL = "trial"
  FREE = "free"
  ACTIVE = "active"  
  SUSPENDED = "suspended"              

  
  def trigger
    if event_monitored? and not_api_source? or sync_for_all_sources?
      send(params[:event_type], params[:content])
    end

    if LIVE_CHAT_EVENTS.include? params[:event_type]
      Resque.enqueue(Workers::Livechat, 
        {
          :worker_method => "update_site", 
          :siteId        => current_account.chat_setting.display_id, 
          :attributes    => { :next_renewal_at => current_account.subscription_next_renewal_at,
                              :suspended => !current_account.active?
                             }
        }
      )
    end

    Account.reset_current_account
    respond_to do |format|
      format.xml { head 200 }
      format.json  { head 200 }
    end
  end

  def select_shard(&block)
    Sharding.select_shard_of(params[:content][:customer][:id]) do 
        yield 
    end
  end

  private
    #Authentication
    def login_from_basic_auth
      authenticate_or_request_with_http_basic do |username, password|
        password_hash = Digest::MD5.hexdigest(password)
        username == 'freshdesk' && password_hash == "5c8231431eca2c61377371de706a52cc" 
      end
    end

    #Other checks
    def ssl_check
      render :json => ArgumentError, :status => 500 if (Rails.env.production? and !request.ssl?)
    end

    def event_monitored?
      EVENTS.include?(params[:event_type])
    end

    def not_api_source?
      params[:source] != EVENT_SOURCES[:api]
    end

    def sync_for_all_sources?
      SYNC_EVENTS_ALL_SOURCE.include?(params[:event_type])
    end

    def monitored_event_not_from_api?
      event_monitored? and not_api_source? or sync_for_all_sources?  
    end    

    def ensure_right_parameters
      if ((params[:event_type].blank?) or (params[:content].blank?) or params[:content][:customer].blank?)
        return render :json => ArgumentError, :status => 500
      end
    end

    def retrieve_account
      @account = Account.find_by_id(params[:content][:customer][:id])      
      return render :json => ActiveRecord::RecordNotFound, :status => 404 unless @account
      @account.make_current
    end

    #Subscription info
    def load_subscription_info      
      @billing_data = Billing::Subscription.new.retrieve_subscription(@account.id)
      Rails.logger.debug @billing_data
      @subscription_data = subscription_info(@billing_data.subscription, @billing_data.customer)
      Rails.logger.debug @subscription_data.inspect
    end

    def subscription_info(subscription, customer)
      {
        :renewal_period => billing_period(subscription.plan_id),
        :agent_limit => subscription.plan_quantity,
        :state => subscription_state(subscription, customer),
        :next_renewal_at => next_billing(subscription)
      }
    end

    def billing_period(plan_code)
      Billing::Subscription.billing_cycle[plan_code]
    end

    def subscription_state(subscription, customer)
      status =  subscription.status
      
      case
        when (customer.auto_collection.eql?(OFFLINE) and status.eql?(ACTIVE))
          ACTIVE
        when status.eql?(IN_TRIAL)
          TRIAL
        when (status.eql?(ACTIVE) and customer.card_status.eql?(NO_CARD))
          FREE
        when status.eql?(ACTIVE)
          ACTIVE
        when (status.eql?(CANCELLED))
          SUSPENDED
      end   
    end

    def next_billing(subscription)
      if (renewal_date = subscription.current_term_end)
        Time.at(renewal_date).to_datetime.utc
      else
        Time.at(subscription.trial_end).to_datetime.utc
      end
    end

    #Events
    def subscription_changed(content)
      plan = subscription_plan(@billing_data.subscription.plan_id)      
      @old_subscription = @account.subscription.dup
      @existing_addons = @account.addons.dup
      
      @account.subscription.update_attributes(@subscription_data.merge(plan_info(plan)))
      update_addons(@account.subscription, @billing_data.subscription)

      update_features if update_features?
    end

    def subscription_activated(content)
      @account.subscription.update_attributes(@subscription_data)
    end

    def subscription_renewed(content)
      @account.subscription.update_attributes(@subscription_data)
    end

    def subscription_cancelled(content)
      @account.subscription.update_attributes(:state => SUSPENDED)
    end

    def subscription_reactivated(content)
      deleted_customer = DeletedCustomers.find_by_account_id(@account.id)
      deleted_customer.reactivate if deleted_customer
      
      @account.subscription.update_attributes(@subscription_data)
    end

    def card_added(content)
      @account.subscription.set_billing_info(@billing_data.card)
      @account.subscription.save
    end
    alias :card_updated :card_added

    def card_deleted(content)
      @account.subscription.clear_billing_info
      @account.subscription.save
    end

    def payment_succeeded(content)
      payment = @account.subscription.subscription_payments.create(payment_info(content))
      Resque.enqueue(Subscription::UpdateResellerSubscription, { :account_id => @account.id, 
          :event_type => :payment_added, :invoice_id => content[:invoice][:id] })
    end

    def payment_refunded(content)
      @account.subscription.subscription_payments.create(
              :account => @account, :amount => -(content[:transaction][:amount]/100))
    end

    #Plans, addons & features
    def subscription_plan(plan_code)
      plan_id = Billing::Subscription.helpkit_plan[plan_code].to_sym
      plan_name = SubscriptionPlan::SUBSCRIPTION_PLANS[plan_id]
      SubscriptionPlan.find_by_name(plan_name)
    end

    def plan_info(plan)
      {
        :subscription_plan => plan,
        :day_pass_amount => plan.day_pass_amount,
        :free_agents => plan.free_agents
      }
    end

    def update_addons(subscription, billing_subscription)
      addons = billing_subscription.addons.to_a.collect{ |addon| 
        Subscription::Addon.fetch_addon(addon.id) unless ADDONS_TO_IGNORE.include?(addon.id)
      }.compact
      
      plan = subscription_plan(billing_subscription.plan_id)
      subscription.addons = subscription.applicable_addons(addons, plan)
      subscription.save #to update amount in subscription
    end

    def update_features
      SAAS::SubscriptionActions.new.change_plan(@account, @old_subscription, @existing_addons)
    end

    def update_features?            
      @old_subscription.subscription_plan_id != @account.subscription.subscription_plan_id or 
        addons_changed?
    end

    def addons_changed?
      !(@existing_addons & @account.addons == @existing_addons and 
            @account.addons & @existing_addons == @account.addons)
    end

    #Card and Payment info
    def payment_info(content)
      {
        :account => @account,
        :amount => (content[:transaction][:amount].to_f/100 * @account.subscription.currency_exchange_rate.to_f),
        :transaction_id => content[:transaction][:id_at_gateway], 
        :misc => recurring_invoice?(content[:invoice]),
        :meta_info => build_meta_info(content[:invoice])
      }
    end

    def recurring_invoice?(invoice)
      (invoice[:recurring])? INVOICE_TYPES[:recurring] : INVOICE_TYPES[:non_recurring]
    end

    def build_meta_info(invoice)
      meta_info = META_INFO.inject({}) { |h, (k, v)| h[k] = @account.subscription.send(v); h }
      meta_info.merge({ :description => invoice[:line_items][0][:description] })
    end

    # Only a short-term solution. For the long term, billing should be made as a separate APP.
    def determine_pod
      shard = ShardMapping.lookup_with_account_id(params[:content][:customer][:id])
      if shard.nil?
        return # fallback to the current pod.
      elsif shard.pod_info.blank?
        return # fallback to the current pod.
      elsif shard.pod_info != PodConfig['CURRENT_POD']
        Rails.logger.error "Determining billing end point. Current POD #{PodConfig['CURRENT_POD']}"
        redirect_to_pod(shard)
      end
    end

    def redirect_to_pod(shard)
      return if shard.nil?

      # redirect to the correct billing endpoint
      domain = AppConfig["base_domain"][Rails.env]
      redirect_url = "#{request.protocol}billing.#{shard.pod_info}.#{domain}#{request.request_uri}" #Should match with the location directive in Nginx Proxy
      Rails.logger.error "Redirecting to the correct billing endpoint. Redirect URL is #{redirect_url}"

      redirect_to redirect_url
    end

end