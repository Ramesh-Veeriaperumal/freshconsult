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
      offline_customer? && !invoice_invalidated? && !invoice_satisfied?
    end

    def invoice_due_key
      format(INVOICE_DUE, account_id: @account.id)
    end

    def set_invoice_due_key
      set_others_redis_key(invoice_due_key, params[:content][:invoice][:end_date], INVOICE_DUE_EXPIRY)
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
end
