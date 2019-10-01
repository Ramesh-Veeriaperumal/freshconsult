module SubscriptionTestHelper

  def update_subscription
    subscription = Account.current.subscription
    subscription.card_number = Faker::Number.number(10)
    subscription.save
  end

  def central_publish_post_pattern(subscription)
    {
      id: subscription.id,
      amount: subscription.amount.to_i,
      card_number: subscription.card_number,
      card_expiration: subscription.card_expiration,
      state: subscription.state,
      subscription_plan_id: subscription.subscription_plan_id,
      account_id: subscription.account_id,
      renewal_period: subscription.renewal_period,
      billing_id: subscription.billing_id,
      subscription_discount_id: subscription.subscription_discount_id,
      subscription_affiliate_id: subscription.subscription_affiliate_id,
      agent_limit: subscription.agent_limit,
      free_agents: subscription.free_agents,
      day_pass_amount: subscription.day_pass_amount.to_i,
      subscription_currency_id: subscription.subscription_currency_id,
      created_at: subscription.created_at.try(:utc).try(:iso8601),
      updated_at: subscription.updated_at.try(:utc).try(:iso8601),
      next_renewal_at: subscription.next_renewal_at.try(:utc).try(:iso8601),
      discount_expires_at: subscription.discount_expires_at.try(:utc).try(:iso8601),
      account_plan: subscription.subscription_plan.display_name,
      currency: subscription.currency.name,
      exchange_rate: subscription.currency.exchange_rate
    }
  end

  def event_info_pattern
    {
      ip_address: Thread.current[:current_ip],
      pod: ChannelFrameworkConfig['pod']
    }
  end

  def stub_update_params(account_id)
    {
      subscription:
       {
         id: account_id, plan_id: 'blossom_jan_19_annual',
         plan_quantity: 1, status: 'active', trial_start: 1_556_863_974,
         trial_end: 1_556_864_678, current_term_start: 1_557_818_479,
         current_term_end: 1_589_440_879, created_at: 1_368_442_623,
         started_at: 1_368_442_623, activated_at: 1_556_891_503,
         has_scheduled_changes: false, object: 'subscription',
         coupon: '1FREEAGENT', coupons: [{ coupon_id: '1FREEAGENT',
                                           applied_count: 38, object: 'coupon' }], due_invoices_count: 0
       },
      customer: { id: 1, first_name: 'Ethan hunt',
                  last_name: 'Ethan hunt', email: 'meaghan.bergnaum@kaulke.com',
                  company: 'freshdesk', auto_collection: 'on',
                  allow_direct_debit: false, created_at: 1_368_442_623,
                  taxability: 'taxable', object: 'customer',
                  billing_address: { first_name: 'asdasd', last_name: 'asdasasd',
                                     line1: 'A14, Sree Prasad Apt, Jeswant Nagar, Mugappair West',
                                     city: 'Chennai', state_code: 'TN', state: 'Tamil Nadu',
                                     country: 'IN', zip: 600_037, object: 'billing_address' },
                  card_status: 'valid',
                  payment_method: { object: 'payment_method', type: 'card',
                                    reference_i: 'tok_HngTopzRQR3BKK1E17', gateway: 'chargebee',
                                    status: 'valid' },
                  account_credits: 0, refundable_credits: 4_553_100, excess_payments: 0,
                  cf_account_domain: 'aut.freshpo.com', meta_data: { customer_key: 'fdesk.1' } },
      card: { status: 'valid', gateway: 'chargebee', first_name: 'sdasd',
              last_name: 'asdasd', iin: 411_111, last4: 1111, card_type: 'visa',
              expiry_month: 12, expiry_year: 2020, billing_addr1: 'A14, Sree Prasad Apt',
              billing_addr2: 'Jeswant Nagar, Mugappair West', billing_city: 'Chennai',
              billing_state_code: 'TN', billing_state: 'Tamil Nadu', billing_country: 'IN',
              billing_zip: 600_037, ip_address: '182.73.13.166', object: 'card',
              masked_number: '************1111', customer_id: '1' }
    }
  end
end
