module Billing::OmniSubscriptionUpdateMethods
  BILLING_PERIOD = {
    monthly: ['month', 1].freeze,
    quarterly: ['quarter', 3].freeze,
    six_month: ['six-month', 6].freeze,
    annual: ['annual', 12].freeze
  }.freeze

  def construct_payload(chargebee_result)
    {
      organisationId: Account.current.organisation.try(:id),
      type: chargebee_result[:event_type],
      accountId: Account.current.id,
      payload: {
        vendor_name: 'chargebee',
        transaction_id: begin
                          chargebee_result[:content][:invoice][:linked_transactions].first['txn_id']
                        rescue => e
                          ''
                        end,
        bundle_id: Account.current.omni_bundle_id,
        event_payload: {
          id: chargebee_result[:id],
          occurred_at: chargebee_result[:occurred_at],
          source: chargebee_result[:source],
          user: chargebee_result[:content][:customer][:email],
          object: chargebee_result[:object],
          api_version: 'v2',
          event_type: chargebee_result[:event_type]
        }.merge!(content: construct_content_payload(chargebee_result[:content]))
      }
    }
  end

  def construct_content_payload(result)
    { subscription: construct_subscription_payload(result[:subscription], result[:customer]),
      customer: construct_customer_payload(result[:customer]) }
  end

  def construct_subscription_payload(subscription, customer)
    result = {
      id: subscription[:id],
      customer_id: customer[:id],
      plan_id: subscription[:plan_id],
      plan_quantity: subscription[:plan_quantity],
      plan_unit_price: '',
      plan_amount: Account.current.subscription.amount.to_i,
      billing_period: BILLING_PERIOD[subscription[:plan_id].split('_').last.to_sym][1],
      billing_period_unit: BILLING_PERIOD[subscription[:plan_id].split('_').last.to_sym][0],
      plan_free_quantity: 0,
      status: subscription[:status],
      trial_start: subscription[:trial_start],
      trial_end: subscription[:trial_end],
      next_billing_at: Account.current.subscription.next_renewal_at.to_i,
      created_at: subscription[:created_at],
      started_at: subscription[:started_at],
      # updated_at: '', #optional
      has_scheduled_changes: subscription[:has_scheduled_changes],
      # resource_version: '', #optional
      deleted: subscription[:deleted],
      object: 'subscription',
      currency_code: Account.current.subscription.currency.name,
      due_invoices_count: subscription[:due_invoices_count]
    }
    result.merge!(addons: subscription[:addons]) if subscription[:addons].present?
    result
  end

  def construct_customer_payload(customer)
    result = {
      id: customer[:id],
      auto_collection: customer[:auto_collection],
      net_term_days: 0,
      allow_direct_debit: customer[:allow_direct_debit],
      created_at: customer[:created_at],
      taxability: customer[:taxability],
      # updated_at: '', #optional
      pii_cleared: 'active',
      # resource_version: '', #optional
      deleted: false,
      object: 'customer',
      card_status: customer[:card_status],
      promotional_credits: 0,
      refundable_credits: customer[:refundable_credits],
      excess_payments: customer[:excess_payments],
      unbilled_charges: 0,
      preferred_currency_code: Account.current.subscription.currency.name
    }
    result.merge!(billing_address: customer[:billing_address]) if customer[:billing_address].present?
    result
  end
end
