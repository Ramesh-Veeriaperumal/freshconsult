module Billing::BillingHelper
  include Billing::Constants
  private
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
      fsm_addon = subscription.addons.find { |addon| addon.name == Subscription::Addon::FSM_ADDON }
      existing_field_agent_limit = subscription.field_agent_limit
      if fsm_addon
        new_field_agent_limit = billing_subscription.addons.find { |addon| addon.id ==
          fsm_addon.billing_addon_id.to_s }.quantity
        subscription.field_agent_limit = new_field_agent_limit
        if existing_field_agent_limit && new_field_agent_limit < existing_field_agent_limit
          params = { account_id: subscription.account_id, old_field_agent_limit: existing_field_agent_limit, new_field_agent_limit: new_field_agent_limit }
          msg = 'FSM addon quantity dropped from Chargebee. There may be additional (no more charged) field agents in Freshdesk'
          Rails.logger.info " #{msg} #{params.inspect}"
          Admin::AdvancedTicketing::FieldServiceManagement::Util.notify_fsm_dev(msg, params)
        end
      else
        subscription.reset_field_agent_limit
      end
    end

    def has_pending_downgrade_request?(account)
      account.launched?(:downgrade_policy) && account.subscription.subscription_request.present?
    end

    def has_scheduled_changes?(content)
      content[:subscription][:has_scheduled_changes]
    end
end
