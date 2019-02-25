class Billing::BillingController < ApplicationController

  include Redis::RedisKeys
  include Redis::OthersRedis
  include Billing::Constants
  include Billing::BillingHelper

  skip_before_filter :check_privilege, :verify_authenticity_token,
                      :set_current_account, :set_time_zone, :set_locale, 
                      :check_account_state, :ensure_proper_protocol, :ensure_proper_sts_header,
                      :check_day_pass_usage, :redirect_to_mobile_url

  skip_after_filter :set_last_active_time

  # Authentication, SSL and Events to be tracked or not. This must be the last prepend_before_filter
  # for this controller 
  prepend_before_filter :event_monitored, :ssl_check, :login_from_basic_auth

  before_filter :ensure_right_parameters, :retrieve_account, 
                :load_subscription_info
 

  def trigger
    if (not_api_source? or sync_for_all_sources?) && INVOICE_EVENTS.exclude?(params[:event_type])
      safe_send(params[:event_type], params[:content])
    end

    if LIVE_CHAT_EVENTS.include? params[:event_type]
      retrieve_account unless @account
      if @account && @account.chat_setting && @account.subscription && @account.chat_setting.site_id
          Livechat::Sync.new.sync_account_state({ :expires_at => @account.subscription.next_renewal_at.utc, :suspended => !@account.active? })
      end
    end

    handle_due_invoices if check_due_invoices?

    Account.reset_current_account
    respond_to do |format|
      format.xml { head 200 }
      format.json  { head 200 }
    end
  end

  def select_shard(&block)
    Sharding.select_shard_of(customer_id_param) do 
        yield 
    end
  end

  private 

    # Authentication

    def login_from_basic_auth
      authenticate_or_request_with_http_basic do |username, password|
        password_hash = Digest::MD5.hexdigest(password)
        username == 'freshdesk' && password_hash == "5c8231431eca2c61377371de706a52cc" 
      end
    end

    # Other checks
    def ssl_check
      render :json => ArgumentError, :status => 500 if (Rails.env.production? and !request.ssl?)
    end

    def event_monitored
      unless EVENTS.include?(params[:event_type])
        respond_to do |format|
          format.xml { head 200 }
          format.json  { head 200 }
        end
      end
    end

    def not_api_source?
      params[:source] != EVENT_SOURCES[:api]
    end

    def sync_for_all_sources?
      SYNC_EVENTS_ALL_SOURCE.include?(params[:event_type])
    end   

    def ensure_right_parameters
      if ((params[:event_type].blank?) or (params[:content].blank?) or customer_id_param.blank?)
        return render :json => ArgumentError, :status => 500
      end
    end

    def retrieve_account
      @account = Account.find_by_id(customer_id_param)      
      if @account
        @account.make_current
      else
        if params[:event_type] == "subscription_cancelled"
          respond_to do |format|
            format.xml { head 200 }
            format.json  { head 200 }
          end
        else
          return render :json => ActiveRecord::RecordNotFound, :status => 404 
        end
      end
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
      @account.account_additional_settings.set_payment_preference(@billing_data.subscription.cf_reseller)
      if plan_changed? && omni_plan_change?
       ProductFeedbackWorker.perform_async(omni_channel_ticket_params)
      end
    end

    def subscription_activated(content)
      @account.subscription.update_attributes(@subscription_data)
    end

    def subscription_renewed(content)

      @account.subscription.update_attributes(@subscription_data)
      if redis_key_exists?(card_expiry_key)
         value = { "next_renewal" => @subscription_data[:next_renewal_at]}
         set_others_redis_hash(card_expiry_key,value)
      end
    end

    def subscription_cancelled(content)
      @account.subscription.update_attributes(:state => SUSPENDED)
      remove_others_redis_key(card_expiry_key)
    end

    def subscription_reactivated(content)
      deleted_customer = DeletedCustomers.find_by_account_id(@account.id)
      deleted_customer.reactivate if deleted_customer
      
      @account.subscription.update_attributes(@subscription_data)
    end

    def card_added(content)
      @account.subscription.set_billing_info(@billing_data.card)
      @account.subscription.save
      if content['customer']['card_status'] == CARD_STATUS
        remove_others_redis_key(card_expiry_key)
      end
    end
    alias :card_updated :card_added

    def card_deleted(content)
      @account.subscription.clear_billing_info
      @account.subscription.save
      auto_collection_off_trigger
    end

    def card_expiring(content)
      if content['customer']['auto_collection'] == ONLINE_CUSTOMER
          value = { "next_renewal" => @subscription_data[:next_renewal_at], "card_expiry_date" => DateTime.now.utc + 30.days}
        set_others_redis_hash(card_expiry_key,value)
      end
    end

    def customer_changed(content)
      if content['customer'] and content['customer']['auto_collection'] and content['customer']['auto_collection'] == OFFLINE
        auto_collection_off_trigger 
      end
    end

    def payment_succeeded(content)
      payment = @account.subscription.subscription_payments.create(payment_info(content))
      Subscription::UpdatePartnersSubscription.perform_async({ :account_id => @account.id, 
          :event_type => :payment_added, :invoice_id => content[:invoice][:id] })
      store_invoice(content) if @account.subscription.affiliate.nil?
    end

    def payment_refunded(content)
      @account.subscription.subscription_payments.create(
              :account => @account, :amount => -(content[:transaction][:amount]/100))
      invoice_hash = Billing::WebhookParser.new(content).invoice_hash
      invoice =  @account.subscription.subscription_invoices.find_by_chargebee_invoice_id(invoice_hash[:chargebee_invoice_id])
      
      invoice.update_attributes(invoice_hash) if invoice.present?
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
      SAAS::SubscriptionEventActions.new(@account, @old_subscription, @existing_addons).change_plan
      if Account.current.active_trial.present?
        Account.current.active_trial.update_result!(@old_subscription, Account.current.subscription)
      end
    end

    def update_features?
      plan_changed? || addons_changed?
    end

    def plan_changed?
      @old_subscription.subscription_plan_id != @account.subscription.subscription_plan_id
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
      meta_info = META_INFO.inject({}) { |h, (k, v)| h[k] = @account.subscription.safe_send(v); h }
      meta_info.merge({ :description => invoice[:line_items][0][:description] })
    end

    # Only a short-term solution. For the long term, billing should be made as a separate APP.
    def determine_pod
      shard = ShardMapping.lookup_with_account_id(customer_id_param)
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

    def store_invoice(content)
      if content["invoice"]["id"] and content['customer']['auto_collection'] == ONLINE_CUSTOMER and content["invoice"]["status"] == PAID
        invoice_hash = Billing::WebhookParser.new(content).invoice_hash
        @account.subscription.subscription_invoices.create(invoice_hash)
      end
    end

    def auto_collection_off_trigger
      Subscription::UpdatePartnersSubscription.perform_async({ :account_id => @account.id, 
            :event_type => :auto_collection_off })
    end
end
