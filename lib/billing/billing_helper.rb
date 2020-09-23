module Billing::BillingHelper
  include SubscriptionsHelper
  include Billing::Constants
  private

    def throttle_subscription_renewal?(agent_seats, plan_id, new_addons, account)
      agent_seats != account.subscription.agent_limit ||
        Billing::Subscription.helpkit_plan[plan_id].to_sym != account.plan_name ||
        new_addons.present? && account.subscription.addons.any? do |addon|
          matched_new_addon = new_addons.find { |new_addon| new_addon[:id].to_sym == addon.billing_addon_id }
          matched_new_addon.present? && addon.addon_type != Subscription::Addon::ADDON_TYPES[:on_off] && matched_new_addon[:quantity] != addon.billing_quantity(account.subscription)
        end
    end

    def customer_id_param
      if INVOICE_EVENTS.include?(params[:event_type])
        params[:content][:invoice][:customer_id]
      else
        params[:content][:customer][:id]
      end
    end

    def check_due_invoices?
      ALL_INVOICE_EVENTS.include?(params[:event_type])
    end

    def offline_customer?
      @billing_data.customer.auto_collection.eql?(OFFLINE)
    end

    def handle_due_invoices
      return if non_recurring?
      if redis_key_exists?(invoice_due_key)
        remove_others_redis_key(invoice_due_key) if remove_invoice_due_key?
      elsif set_invoice_due_key?
        set_invoice_due_key
      end
    end

    def remove_invoice_due_key?
      (invoice_invalidated? || invoice_satisfied?)
    end

    def set_invoice_due_key?
      offline_customer? && !invoice_invalidated? && params[:content][:invoice][:status] == PAYMENT_DUE
    end

    def invoice_due_key
      format(INVOICE_DUE, account_id: @account.id)
    end

    def set_invoice_due_key
      set_others_redis_key(invoice_due_key, params[:occurred_at], INVOICE_DUE_EXPIRY)
    end

    def invoice_invalidated?
      ['subscription_cancelled', 'invoice_deleted'].include?(params[:event_type])
    end

    def invoice_satisfied?
      [PAID, VOIDED].include?(params[:content][:invoice][:status])
    end

    def non_recurring?
      (params[:content][:invoice] && !params[:content][:invoice][:recurring])
    end

    def card_expiry_key
      format(CARD_EXPIRY_KEY, account_id: @account.id)
    end

    def update_field_agent_limit(subscription, billing_subscription)
      result = false
      fsm_addon = subscription.addons.find { |addon| SubscriptionConstants::FSM_ADDON_PARAMS_NAMES_MAP.key?(addon.name) }
      if fsm_addon
        new_field_agent_limit = billing_subscription.addons.find { |addon| addon.id == fsm_addon.billing_addon_id.to_s }.quantity
        result = field_agent_quantity_exceeded?(new_field_agent_limit)
        subscription.field_agent_limit = result ? @account.field_agents_count : new_field_agent_limit
      else
        subscription.reset_field_agent_limit
      end
      result
    end

    def freddy_subscription_info(subscription, billing_subscription)
      {}.tap do |freddy_info|
        freddy_info[:freddy_session_packs] = freddy_session_packs_count(subscription, billing_subscription)
        freddy_info[:freddy_billing_model] = billing_subscription.cf_freddy_billing_model
        freddy_info[:freddy_sessions] = updated_freddy_sessions(subscription, billing_subscription)
      end
    end

    def freddy_session_packs_count(subscription, billing_subscription)
      session_pack_addon = subscription.addons.find { |addon| SubscriptionConstants::FREDDY_SESSION_PACK_ADDONS.include?(addon.name) }
      billing_subscription.addons.find { |addon| addon.id == session_pack_addon.billing_addon_id.to_s }.quantity if session_pack_addon.present?
    end

    def updated_freddy_sessions(subscription, billing_subscription)
      chargebee_plan_id = billing_subscription.plan_id
      sub_plan_name = Billing::Subscription.helpkit_plan[chargebee_plan_id].to_sym
      sub_renewal_period = billing_period(chargebee_plan_id)
      calculate_freddy_session(subscription.addons, subscription, sub_plan_name, sub_renewal_period)
    end

    def agent_quantity_exceeded?(billing_subscription)
      billing_subscription.plan_quantity && billing_subscription.plan_quantity < @account.full_time_support_agents.count
    end

    def has_pending_downgrade_request?(account)
      account.launched?(:downgrade_policy) && account.subscription.subscription_request.present?
    end

    def has_scheduled_changes?(content)
      content[:subscription][:has_scheduled_changes]
    end

    def field_agent_quantity_exceeded?(new_field_agent_limit)
      new_field_agent_limit && new_field_agent_limit < @account.field_agents_count
    end

    def billing_period(plan_code)
      Billing::Subscription.billing_cycle[plan_code]
    end

    def subscription_plan(plan_code)
      plan_id = Billing::Subscription.helpkit_plan[plan_code].to_sym
      plan_name = SubscriptionPlan::SUBSCRIPTION_PLANS[plan_id]
      SubscriptionPlan.find_by_name(plan_name)
    end

    def subscription_info(subscription, customer)
      {
        renewal_period: billing_period(subscription.plan_id),
        agent_limit: Subscription::NEW_SPROUT.include?(subscription_plan(subscription.plan_id).name) ? DEFAULT_AGENT_LIMIT : subscription.plan_quantity,
        state: subscription_state(subscription, customer),
        next_renewal_at: next_billing(subscription)
      }
    end

    def subscription_state(subscription, customer)
      status = subscription.status
      if customer.auto_collection.eql?(OFFLINE) && status.eql?(ACTIVE)
        ACTIVE
      elsif status.eql?(IN_TRIAL)
        TRIAL
      elsif status.eql?(ACTIVE) && customer.card_status.eql?(NO_CARD)
        FREE
      elsif status.eql?(ACTIVE)
        ACTIVE
      elsif status.eql?(CANCELLED)
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

    def construct_subscription_data(event_data)
      Rails.logger.debug event_data
      subscription_info(event_data.subscription, event_data.customer)
    end

    def event_eligible_to_process?
      (not_api_source? || sync_for_all_sources?) && INVOICE_EVENTS.exclude?(params[:event_type])
    end

    def not_api_source?
      params[:source] != EVENT_SOURCES[:api]
    end

    def sync_for_all_sources?
      SYNC_EVENTS_ALL_SOURCE.include?(params[:event_type])
    end

    def trigger_omni_subscription_callbacks
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
end
