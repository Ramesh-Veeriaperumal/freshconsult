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
      addons: subscription.send('format_addons', subscription.addons),
      freddy_sessions: subscription.freddy_sessions.to_i,
      freddy_session_packs: subscription.freddy_session_packs,
      freddy_billing_model: subscription.freddy_billing_model,
      day_pass_amount: subscription.day_pass_amount.to_i,
      subscription_currency_id: subscription.subscription_currency_id,
      created_at: subscription.created_at.try(:utc).try(:iso8601),
      updated_at: subscription.updated_at.try(:utc).try(:iso8601),
      next_renewal_at: subscription.next_renewal_at.try(:utc).try(:iso8601),
      discount_expires_at: subscription.discount_expires_at.try(:utc).try(:iso8601),
      account_plan: subscription.subscription_plan.display_name,
      plan_name: subscription.subscription_plan.name,
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
         trial_end: 1_556_864_678, current_term_start: 1.day.ago.to_i,
         current_term_end: 1.day.from_now.to_i, created_at: 1_368_442_623,
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

  def stub_estimate_params
    {
      estimate:
         {
           created_at: 1_565_933_968, recurring: true, subscription_id: '11', subscription_status: 'in_trial',
           term_ends_at: 1_577_182_206, collect_now: false, price_type: 'tax_exclusive', amount: 740_900,
           credits_applied: 0, amount_due: 740_900, object: 'estimate', sub_total: 705_600,
           line_items: [{ date_from: 1_577_182_206, date_to: 1_608_804_606, unit_amount: 58_800,
                          quantity: 12, amount: 705_600, is_taxed: true, tax: 35_280, tax_rate: 5.0, object: 'line_item',
                          description: 'Estate Annual plan', type: 'charge', entity_type: 'plan', entity_id: 'estate_jan_17_annual' }],
           taxes: [{ object: 'tax', description: 'IND TAX @ 5%', amount: 35_280 }]
         }
    }
  end

  def stub_chargebee_coupon
    {
      coupon:
        {
          id: '1FREEAGENT', name: '1 free agent', invoice_name: '1 free agent',
          discount_type: 'offer_quantity', discount_quantity: 1, duration_type: 'forever',
          status: 'active', apply_discount_on: 'not_applicable', apply_on: 'each_specified_item',
          plan_constraint: 'all', addon_constraint: 'none', created_at: 1_430_995_878,
          object: 'coupon', redemptions: 22
        }
    }
  end

  def stub_chargebee_plan
    {
      plan:
        {
          id: 'blossom_jan_19_monthly', name: 'Blossom Monthly plan 2019', invoice_name: 'Blossom Monthly plan',
          price: 1900, period: 1, period_unit: 'month', trial_period: 26, trial_period_unit: 'day',
          free_quantity: 0, status: 'active', enabled_in_hosted_pages: true, enabled_in_portal: true,
          object: 'plan', charge_model: 'per_unit', taxable: true
        }
    }
  end

  def stub_remove_scheduled_changes
    { subscription: { id: '666000000106', plan_id: 'forest_jan_20_annual',
                      plan_quantity: 5, status: 'active', trial_start: 1_573_223_922, trial_end: 1_573_224_078,
                      current_term_start: 1_582_130_019, current_term_end: 1_613_752_419, created_at: 1_570_165_028,
                      started_at: 1_570_165_028, activated_at: 1_573_224_087, has_scheduled_changes: false,
                      object: 'subscription', coupon: '1FREEAGENT', coupons: [{ coupon_id: '1FREEAGENT',
                                                                                applied_count: 10, object: 'coupon' }], due_invoices_count: 0,
                      cf_currency_change: 'EUR', cf_test_reseller_card: 'False' },
      customer: { id: '666000000106', first_name: 'sadfsa', last_name: 'sadfs',
                  email: 'fdseafarers.1@gmail.com', company: 'seafarers300', auto_collection: 'on',
                  allow_direct_debit: false, created_at: 1_570_165_028, taxability: 'taxable', object: 'customer',
                  billing_address: { first_name: 'John', last_name: 'Mayor', line1: 'Sp Infocity Perungudi',
                                     city: 'Chennai', state_code: 'TN', state: 'Tamil Nadu', country: 'IN', zip: '600096',
                                     object: 'billing_address' }, card_status: 'valid', payment_method: { object: 'payment_method',
                                                                                                          type: 'card', reference_id: 'cus_FvaD9F4NnDz0aP/pm_1FPj33LvKhTHHgNwZxOemy0E', gateway: 'stripe',
                                                                                                          status: 'valid' }, account_credits: 0, refundable_credits: 174_900, excess_payments: 0,
                  cf_account_domain: 'seafarers300.freshpo.com', cf_test_reseller_card: 'False',
                  meta_data: { customer_key: 'fdesk.666000000106' } }, card: { status: 'valid',
                                                                               gateway: 'stripe', first_name: 'John', last_name: 'Mayor', iin: '******',
                                                                               last4: '4242', card_type: 'visa', expiry_month: 12, expiry_year: 2020,
                                                                               billing_addr1: 'Sp Infocity', billing_addr2: 'Perungudi', billing_city: 'Chennai',
                                                                               billing_state_code: 'TN', billing_state: 'Tamil Nadu', billing_country: 'IN',
                                                                               billing_zip: '600096', object: 'card', masked_number: '************4242',
                                                                               customer_id: '666000000106', reference_id: 'cus_FvaD9F4NnDz0aP/pm_1FPj33LvKhTHHgNwZxOemy0E' } }
  end

  def get_new_subscription_request(account, plan_id, renewal_period)
    new_subscription_request = account.subscription.build_subscription_request
    new_subscription_request.plan_id = plan_id
    new_subscription_request.renewal_period = renewal_period
    new_subscription_request.save
    new_subscription_request
  end
end
