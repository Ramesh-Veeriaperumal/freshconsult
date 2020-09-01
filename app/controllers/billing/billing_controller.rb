class Billing::BillingController < ApplicationController

  include Redis::OthersRedis
  include Redis::RedisKeys
  include Billing::Constants
  include Billing::BillingHelper
  include Billing::ChargebeeOmniUpgradeHelper
  include SubscriptionHelper

  skip_before_filter :check_privilege, :verify_authenticity_token,
                     :set_current_account, :set_time_zone, :set_locale,
                     :check_account_state, :ensure_proper_protocol, :ensure_proper_sts_header,
                     :check_day_pass_usage, :redirect_to_mobile_url, :check_session_timeout

  skip_after_filter :set_last_active_time

  # Authentication, SSL and Events to be tracked or not. This must be the last prepend_before_filter
  # for this controller 
  prepend_before_filter :event_monitored, :ssl_check, :login_from_basic_auth

  before_filter :ensure_right_parameters, :retrieve_account, 
                :load_subscription_info

  def trigger
    upgrade_success = handle_chargebee_callback(params[:event_type], params[:content])
    process_live_chat_events if LIVE_CHAT_EVENTS.include?(params[:event_type]) && upgrade_success
    handle_due_invoices if check_due_invoices?
    trigger_omni_subscription_callbacks(params)
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

    def handle_chargebee_callback(event_type, content)
      upgrade_success = true
      if event_eligible_to_process?(event_type)
        plan = subscription_plan(content[:subscription][:plan_id])
        upgrade_success = handle_omni_upgrade_via_chargebee if omni_plan_upgrade?(event_type, plan.name)
        safe_send(event_type, content) if upgrade_success
      end
      upgrade_success
    end

    def process_live_chat_events
      retrieve_account unless @account
      Livechat::Sync.new.sync_account_state(expires_at: @account.subscription.next_renewal_at.utc, suspended: !@account.active?) if live_chat_setting_enabled?
    end

    def handle_omni_upgrade_via_chargebee
      eligible_for_upgrade = eligible_for_omni_upgrade?
      revert_to_previous_subscription unless eligible_for_upgrade
      eligible_for_upgrade
    end

    def trigger_omni_subscription_callbacks(params)
      if omni_bundle_account?
        Rails.logger.info "Pushing event data for Freshcaller/Freshchat product account-id: #{@account.id}"
        Billing::FreshcallerSubscriptionUpdate.perform_async(params)
        Billing::FreshchatSubscriptionUpdate.perform_async(params)
      end
    end

    def live_chat_setting_enabled?
      @account&.chat_setting && @account&.subscription && @account.chat_setting.site_id
    end

    def omni_bundle_account?
      @account.present? && @account.make_current && @account.omni_bundle_account?
    end

    def event_eligible_to_process?(event_type)
      (not_api_source? || sync_for_all_sources?) && INVOICE_EVENTS.exclude?(event_type)
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

    def revert_to_previous_subscription
      Billing::Subscription.new.update_subscription(@account.subscription, false, @account.addons)
    end

    #Events
    def subscription_changed(content)
      plan = subscription_plan(@billing_data.subscription.plan_id)
      @old_subscription = @account.subscription.dup
      @existing_addons = @account.addons.dup
      subscription_request = @account.subscription.subscription_request
      billing_subscription = @billing_data.subscription
      subscription_hash = {}
      update_applicable_addons(@account.subscription, billing_subscription)
      account_addons_features = @account.addons.collect(&:features).flatten.uniq
      product_loss = product_loss_in_new_plan?(@account, plan, account_addons_features)
      subscription_request.destroy if has_pending_downgrade_request?(@account) && !has_scheduled_changes?(content)
      if plan.name != @account.subscription.subscription_plan.name && product_loss
        subscription_hash.merge!(plan_info(@account.subscription.subscription_plan))
      else
        @account.subscription.subscription_plan = plan
      end
      subscription_hash[:agent_limit] = @account.subscription.agent_limit = @account.full_time_support_agents.count if agent_quantity_exceeded?(billing_subscription)
      subscription_hash[:field_agent_limit] = @account.subscription.field_agent_limit if update_field_agent_limit(@account.subscription, billing_subscription)
      subscription_hash = update_freddy_details(@account, subscription_hash, billing_subscription)
      if subscription_hash.present?
        @account.subscription.renewal_period = @subscription_data[:renewal_period]
        @account.subscription.state = @subscription_data[:state] if @subscription_data[:state].present?
        Billing::Subscription.new.update_subscription(@account.subscription, true, @account.subscription.addons)
        @subscription_data.merge!(subscription_hash)
      end
      additional_info = @account.subscription.additional_info || {}
      additional_info[:auto_collection] = Subscription::AUTO_COLLECTION[@billing_data.customer.auto_collection]
      additional_info[:freddy_billing_model] = @billing_data.subscription.cf_freddy_billing_model
      @subscription_data[:additional_info] = additional_info
      @subscription_data.merge!(plan_info(plan)) if @subscription_data[:subscription_plan].blank?
      @subscription_data.delete(:state) if @subscription_data[:state].blank?
      @account.subscription.update_attributes(@subscription_data)
      update_features if update_features?
      @account.account_additional_settings.set_payment_preference(@billing_data.subscription.cf_reseller)
    end

    def subscription_activated(content)
      @account.subscription.update_attributes(@subscription_data)
    end

    def subscription_renewed(content)
      if throttle_subscription_renewal?(content[:subscription][:plan_quantity], content[:subscription][:plan_id],
                                        content[:subscription][:addons], @account)
        Rails.logger.info "Throttling subscription_renewed event for the account #{@account.id}"
        return Billing::ChargebeeEventListener.perform_at(2.minutes.from_now, params.merge(account_id: @account.id))
        
      end
      @account.launch(:downgrade_policy)
      @account.subscription.update_attributes(@subscription_data)
      if redis_key_exists?(card_expiry_key)
        value = { 'next_renewal' => @subscription_data[:next_renewal_at] }
        set_others_redis_hash(card_expiry_key, value)
      end
    end

    def subscription_cancelled(content)
      @account.subscription.update_attributes(:state => SUSPENDED)
      remove_others_redis_key(card_expiry_key)
      if cancellation_requested?
        @account.perform_paid_account_cancellation_actions
      else
        @account.trigger_suspended_account_cleanup
      end
    end

    def subscription_reactivated(content)
      deleted_customer = DeletedCustomers.find_by_account_id(@account.id)
      deleted_customer.reactivate if deleted_customer
      @account.delete_account_cancellation_requested_time_key if cancellation_requested?
      @account.subscription.update_attributes(@subscription_data)
    end

    def subscription_scheduled_cancellation_removed(_content)
      @account.delete_account_cancellation_requested_time_key
    end

    def card_added(content)
      @account.subscription.set_billing_info(@billing_data.card)
      @account.subscription.save
      if content['customer']['card_status'] == CARD_STATUS
        remove_others_redis_key(card_expiry_key)
      end
    end
    alias :card_updated :card_added

    def card_deleted(_content)
      return if @billing_data && @billing_data.card.present?

      @account.subscription.clear_billing_info
      @account.subscription.save
      auto_collection_off_trigger
    end

    def card_expiring(content)
      if content['customer']['auto_collection'] == ONLINE_CUSTOMER
        value = { 'next_renewal' => @subscription_data[:next_renewal_at], 'card_expiry_date' => DateTime.now.utc + 30.days }
        set_others_redis_hash(card_expiry_key, value)
      end
    end

    def customer_changed(content)
      if content['customer'] && content['customer']['auto_collection']
        @account.subscription.mark_auto_collection(content['customer']['auto_collection'])
        auto_collection_off_trigger if content['customer']['auto_collection'] == OFFLINE
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

    def plan_info(plan)
      {
        :subscription_plan => plan,
        :day_pass_amount => plan.day_pass_amount,
        :free_agents => plan.free_agents
      }
    end

    def update_addons(subscription, billing_subscription)
      update_applicable_addons(subscription, billing_subscription)
      subscription.save #to update amount in subscription
    end

    def update_applicable_addons(subscription, billing_subscription)
      addons = billing_subscription.addons.to_a.collect{ |addon| 
        Subscription::Addon.fetch_addon(addon.id) unless ADDONS_TO_IGNORE.include?(addon.id)
      }.compact
      
      plan = subscription_plan(billing_subscription.plan_id)
      subscription.addons = subscription.applicable_addons(addons, plan)
    end

    def update_features
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

    def cancellation_requested?
      @account.launched?(:downgrade_policy) && @account.account_cancellation_requested?
    end
end
