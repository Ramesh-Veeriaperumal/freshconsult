module Billing::OmniSubscriptionUpdateMethods
  BILLING_PERIOD = {
    monthly: ['month', 1].freeze,
    quarterly: ['quarter', 3].freeze,
    yearly: ['six-month', 6].freeze, # originally half_yearly
    annual: ['annual', 12].freeze
  }.freeze

  def construct_payload_for_ui_update(response)
    {
      id: request.uuid,
      event_type: 'subscription_changed',
      occurred_at: Time.now.utc.to_i,
      source: 'admin_action',
      object: 'event',
      api_version: 'v1',
      content: {
        subscription: {
          id: response.subscription.id,
          plan_id: response.subscription.plan_id,
          plan_quantity: response.subscription.plan_quantity,
          status: response.subscription.status,
          trial_start: response.subscription.trial_start,
          trial_end: response.subscription.trial_end,
          created_at: response.subscription.created_at,
          started_at: response.subscription.started_at,
          has_scheduled_changes: response.subscription.has_scheduled_changes,
          object: response.subscription.object,
          due_invoices_count: response.subscription.due_invoices_count,
          cf_test_reseller_card: response.subscription.cf_test_reseller_card
        },
        customer: {
          id: response.customer.id,
          first_name: response.customer.first_name,
          last_name: response.customer.last_name,
          email: response.customer.email,
          company: response.customer.company,
          auto_collection: response.customer.auto_collection,
          allow_direct_debit: response.customer.allow_direct_debit,
          created_at: response.customer.created_at,
          taxability: response.customer.taxability,
          object: response.customer.object,
          card_status: response.customer.card_status,
          account_credits: response.customer.account_credits,
          refundable_credits: response.customer.refundable_credits,
          excess_payments: response.customer.excess_payments,
          cf_account_domain: response.customer.cf_account_domain,
          cf_test_reseller_card: response.customer.cf_test_reseller_card,
          meta_data: {
            customer_key: response.customer.meta_data[:customer_key]
          }
        }
      }
    }
  end

  def construct_payload_for_conversion(response, id, event_type)
    response = response.deep_symbolize_keys
    {
      id: id,
      event_type: event_type,
      occurred_at: Time.now.utc.to_i,
      source: 'admin_action',
      object: 'event',
      api_version: 'v1',
      content: {
        subscription: response[:subscription].deep_symbolize_keys,
        customer: response[:customer].deep_symbolize_keys
      }
    }
  end

  def construct_payload(chargebee_result)
    subscription_payload = {
      organisation_id: Account.current.organisation.try(:organisation_id),
      type: chargebee_result[:event_type],
      account_id: Account.current.id,
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
          object: chargebee_result[:object],
          api_version: 'v2',
          event_type: chargebee_result[:event_type]
        }.merge!(content: construct_content_payload(chargebee_result[:content]))
      }
    }
    subscription_payload[:payload][:event_payload][:user] = chargebee_result[:content][:customer][:email] if chargebee_result[:content][:customer].present?
    subscription_payload
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
      deleted: subscription[:deleted] || false,
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
