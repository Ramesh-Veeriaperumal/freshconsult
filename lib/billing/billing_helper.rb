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
      CARD_EXPIRY_KEY % { :account_id => @account.id }
    end

    def omni_channel_ticket_params
      description = 'Customer has switched to / purchased an Omni-channel Freshdesk plan. <br>'
      account_info = "<b>Account ID</b> : #{@account.id} <br>"
      domain_info = "<b>Domain</b> : #{@account.full_domain} <br>"
      previous_plan = "<b>Previous plan</b> : #{@old_subscription.plan_name} <br>"
      new_plan = "<b>Current plan </b> : #{@account.subscription.plan_name} <br>"
      currency = "<b>Currency </b> : #{@account.subscription.currency.name} <br>"
      description << account_info << domain_info << previous_plan << new_plan
      description << currency << 'Change made from chargebee <br>'
      description << 'Ensure plan is set correctly in chat and caller. <br>'
      {
        email: 'billing@freshdesk.com',
        subject: 'Update chat and caller plans',
        status: Helpdesk::Ticketfields::TicketStatus::OPEN,
        priority: TicketConstants::PRIORITY_KEYS_BY_TOKEN[:low],
        description: description.html_safe,
        tags:  'OmnichannelPlan'
      }
    end

    def omni_plan_change?
      @old_subscription.subscription_plan.omni_plan? ||
        @old_subscription.subscription_plan.free_omni_channel_plan? ||
        @account.subscription_plan.omni_plan? || @account.subscription_plan.free_omni_channel_plan?
    end

    def update_field_agent_limit(subscription, billing_subscription)
      result = false
      fsm_addon = subscription.addons.find { |addon| addon.name == Subscription::Addon::FSM_ADDON }
      if fsm_addon
        new_field_agent_limit = billing_subscription.addons.find { |addon| addon.id == fsm_addon.billing_addon_id.to_s }.quantity
        result = field_agent_quantity_exceeded?(new_field_agent_limit)
        subscription.field_agent_limit = result ? @account.field_agents_count : new_field_agent_limit
      else
        subscription.reset_field_agent_limit
      end
      result
    end

    def check_subscribed_seats_availability(subscription, billing_subscription)
      result = agent_quantity_exceeded?(billing_subscription)
      subscription.agent_limit = @account.full_time_support_agents.count if result
      result = true if update_field_agent_limit(subscription, billing_subscription)
      if result
        updated_addons = subscription.addons
        Billing::Subscription.new.update_subscription(subscription, false, updated_addons)
      end
      subscription.save
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
end
