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

end