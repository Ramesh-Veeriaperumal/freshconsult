require_relative '../../test_helper'
class Admin::SubscriptionsControllerTest < ActionController::TestCase

  CHARGEBEE_LIST_PLANS_API_RESPONSE = '{"list":[{"plan":{"id":"sprout_monthly",
    "name":"Sprout Monthly", "invoice_name":"Sprout Monthly 2016","price":1500,
    "period":1,"period_unit":"month","trial_period":30,"trial_period_unit":"day",
    "free_quantity":3,"status":"active"}},{"plan":{"id":
    "estate_quarterly","name":"Estate Quarterly","invoice_name":"Estate Quarterly 2016",
    "price":4900,"period":3,"period_unit":"quarterly","trial_period":30,
    "trial_period_unit":"day","free_quantity":0,"status":"active"}}]}'
  CURRENCY_SYMBOL_MAP = { 'USD' => '$', 'INR' => '₹'}

  def setup
    super
    @currency_map = Hash[Subscription::Currency.all.collect{ |cur| [cur.name, cur] }]
  end

  def test_valid_show
    get :show, construct_params(version: 'private')
    assert_response 200
  end

  def test_show_no_privilege
    stub_admin_tasks_privilege
    get :show, construct_params(version: 'private')
    assert_response 403
    unstub_privilege
  end

  def test_plans_for_account_default_currency
    stub_plans
    get :plans, controller_params(version: 'private')
    assert_response 200
    match_json(plans_response)
    unstub_plans
  end

  def test_plans_with_given_currency_value
    stub_plans('INR')
    get :plans, controller_params(version: 'private', currency: 'INR')
    assert_response 200
    match_json(plans_response('INR'))
    unstub_plans
  end

  def test_plans_for_admin_tasks_privilege
    stub_admin_tasks_privilege
    get :plans, controller_params(version: 'private')
    assert_response 403
    unstub_privilege
  end

  def test_plans_with_invalid_currency
    get :plans, controller_params(version: 'private', currency: 'IN')
    assert_response 400
    match_json([bad_request_error_pattern('currency', :not_included,
      list: Subscription::Currency.currency_names_from_cache.join(','),
      code: :invalid_value)])
  end

  def test_subscription_estimate_without_mandatory_params
    get :estimate, controller_params({ version: 'private' }, false)
    assert_response 400
    match_json([bad_request_error_pattern('agent_seats', :missing_field, code: :missing_field),
                bad_request_error_pattern('renewal_period', :missing_field, code: :missing_field)])
  end

  def test_subscription_estimate_with_invalid_agent_seats
    get :estimate, controller_params({ version: 'private', agent_seats: Faker::Lorem.word, renewal_period: 3 }, false)
    assert_response 400
    match_json([bad_request_error_pattern('agent_seats', :datatype_mismatch, expected_data_type: 'Positive Integer')])
  end

  def test_subscription_estimate_with_invalid_renewal_period
    get :estimate, controller_params({ version: 'private', agent_seats: 1, renewal_period: 2 }, false)
    assert_response 400
    match_json([bad_request_error_pattern('renewal_period', :not_included, list: '1,3,6,12')])
  end

  def test_subscription_estimate_with_string_renewal_period
    get :estimate, controller_params({ version: 'private', agent_seats: 3, renewal_period: Faker::Lorem.word }, false)
    assert_response 400
    match_json([bad_request_error_pattern('renewal_period', :datatype_mismatch, expected_data_type: 'Positive Integer')])
  end

  def test_subscription_estimate_with_invalid_plan
    get :estimate, controller_params({ version: 'private', agent_seats: 1, renewal_period: 1, plan_id: Faker::Number.number(3) }, false)
    assert_response 400
    match_json([bad_request_error_pattern('plan_id', :invalid_plan_id, code: :invalid_value)])
  end

  def test_subscription_estimate_with_invalid_plan_id
    get :estimate, controller_params({ version: 'private', agent_seats: 1, renewal_period: 1, plan_id: Faker::Lorem.word }, false)
    assert_response 400
    bad_request_error_pattern('plan_id', :invalid_plan_id, code: :invalid_value)
  end

  def test_subscription_estimate_with_free_plan
    SubscriptionPlan.any_instance.stubs(:amount).returns(0)
    get :estimate, controller_params({ version: 'private', agent_seats: 1, renewal_period: 12, plan_id: 6 }, false)
    assert_response 400
    bad_request_error_pattern('plan_id', :invalid_plan_id, code: :invalid_value)
  ensure
    SubscriptionPlan.any_instance.unstub(:amount)
  end

  def test_subscription_estimate
    stub_chargebee_requests
    get :estimate, controller_params({ version: 'private', agent_seats: 1, renewal_period: 12, plan_id: SubscriptionPlan.last.id }, false)
    assert_response 200
  ensure
    unstub_chargebee_requests
  end

  private

    def stub_chargebee_requests
      chargebee_estimate = ChargeBee::Estimate.new({})
      Subscription.any_instance.stubs(:active?).returns(true)
      ChargeBee::Subscription.stubs(:retrieve).returns(ChargeBee::Subscription.new({}))
      ChargeBee::Subscription.any_instance.stubs(:subscription).returns(ChargeBee::Subscription.new({}))
      ChargeBee::Subscription.any_instance.stubs(:coupon).returns(nil)
      RestClient::Request.stubs(:execute).returns(immediate_invoice_stub.to_json)
      ChargeBee::Estimate.stubs(:update_subscription).returns(chargebee_estimate)
      ChargeBee::Estimate.any_instance.stubs(:estimate).returns(chargebee_estimate)
      ChargeBee::Estimate::Discount.any_instance.stubs(:amount).returns(1000)
      ChargeBee::Estimate.any_instance.stubs(:discounts).returns([ChargeBee::Estimate::Discount.new({})])
      ChargeBee::Estimate.any_instance.stubs(:amount).returns(1000)
    end

    def unstub_chargebee_requests
      Subscription.any_instance.unstub(:active?)
      ChargeBee::Subscription.unstub(:retrieve)
      ChargeBee::Subscription.any_instance.unstub(:subscription)
      ChargeBee::Subscription.any_instance.unstub(:coupon)
      RestClient::Request.unstub(:execute)
      ChargeBee::Estimate.unstub(:update_subscription)
      ChargeBee::Estimate.any_instance.unstub(:estimate)
      ChargeBee::Estimate::Discount.any_instance.unstub(:amount)
      ChargeBee::Estimate.any_instance.unstub(:discounts)
      ChargeBee::Estimate.any_instance.unstub(:amount)
    end

    def mock_plan(id, plan_name)
      mock_subscription_plan = Minitest::Mock.new
      2.times {
        mock_subscription_plan.expect :name, plan_name
        mock_subscription_plan.expect :id, id
      }
      mock_subscription_plan
    end

    def stub_admin_tasks_privilege(manage_tickets = false)
      User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(false)
    end

    def unstub_privilege
      User.any_instance.unstub(:privilege?)
    end

    def chargebee_plans_api_response_stub(currency_code=nil)
      return CHARGEBEE_LIST_PLANS_API_RESPONSE if currency_code.nil?
      currency_based_response = JSON.parse(CHARGEBEE_LIST_PLANS_API_RESPONSE)
      currency_based_response["list"].each do |plans|
        plans["plan"]["currency_code"] = "INR"
      end
      currency_based_response.to_json
    end

    def stub_plans(currency='USD')
      mock_plans = [mock_plan(1, 'Sprout'), mock_plan(20, 'Estate')]
      SubscriptionPlan.stubs(:cached_current_plans).returns(mock_plans)
      SubscriptionPlan.stubs(:current).returns(mock_plans)
      RestClient::Request.stubs(:execute).with({
        method: :get,
        url: "https://#{@currency_map[currency].billing_site}.chargebee.com/api/v2/plans",
        user: @currency_map[currency].billing_api_key,
        headers: {
          params: {
            limit: 100,
            "id[in]": '[sprout_monthly,sprout_quarterly,sprout_half_yearly,sprout_annual,estate_monthly,estate_quarterly,estate_half_yearly,estate_annual]'
          }
        }
      }).returns(chargebee_plans_api_response_stub(currency))
    end

    def unstub_plans
      SubscriptionPlan.unstub(:current)
      RestClient::Request.unstub(:execute)
    end

    def plans_response(currency='USD')
      [
          {
              "id": 1,
              "name": "Sprout",
              "currency": currency,
              "pricings": [
                  {
                      "billing_cycle": "monthly",
                      "cost_per_agent": "#{CURRENCY_SYMBOL_MAP[currency]}15"
                  },
                  {
                      "billing_cycle": "quarterly",
                      "cost_per_agent": nil
                  },
                  {
                      "billing_cycle": "half_yearly",
                      "cost_per_agent": nil
                  },
                  {
                      "billing_cycle": "annual",
                      "cost_per_agent": nil
                  }
              ]
          },
          {
              "id": 20,
              "name": "Estate",
              "currency": currency,
              "pricings": [
                  {
                      "billing_cycle": "monthly",
                      "cost_per_agent": nil
                  },
                  {
                      "billing_cycle": "quarterly",
                      "cost_per_agent": "#{CURRENCY_SYMBOL_MAP[currency]}16"
                  },
                  {
                      "billing_cycle": "half_yearly",
                      "cost_per_agent": nil
                  },
                  {
                      "billing_cycle": "annual",
                      "cost_per_agent": nil
                  }
              ]
          }
      ]
    end

    def immediate_invoice_stub
      {
        'estimate' => {
          'created_at' =>1559284330,
          'object' => 'estimate',
          'subscription_estimate' => {
            'id' =>'1',
            'status' =>'active',
            'next_billing_at' =>1561876330,
            'object' =>'subscription_estimate',
            'currency_code' =>'USD'
          },
          'invoice_estimate' => {
            'recurring' => true,
            'date' => 1559284330,
            'price_type' => 'tax_exclusive',
            'sub_total' => 5900,
            'total' => 6200,
            'credits_applied' => 6200,
            'amount_paid' => 0,
            'amount_due' => 0,
            'object' => 'invoice_estimate',
            'line_items' => [{
              'id' => 'li_1mbDWbrRS1m8ql2PRG',
              'date_from' => 1559284330,
              'date_to' => 1561876330,
              'unit_amount' => 5900,
              'quantity' => 2,
              'amount' => 11800,
              'pricing_model' => 'per_unit',
              'is_taxed' => true,
              'tax_amount' => 295,
              'tax_rate' => 5.0,
              'object' => 'line_item',
              'subscription_id' =>'1',
              'customer_id' => '1',
              'description' => 'Estate Monthly plan',
              'entity_type' => 'plan',
              'entity_id' => 'estate_jan_17_monthly',
              'discount_amount' => 5900,
              'item_level_discount_amount' => 5900
            }],
            'discounts' => [{
              'object' => 'discount',
              'entity_type' => 'item_level_coupon',
              'description' => '1 free agent',
              'amount' => 5900,
              'entity_id' => '1FREEAGENT'
            }],
            'taxes' => [{
              'object' => 'tax',
              'name' => 'IND TAX',
              'description' => 'IND TAX @ 5%',
              'amount' => 295
            }],
            'line_item_taxes' => [{
              'tax_name' => 'IND TAX',
              'tax_rate' => 5.0,
              'tax_juris_type' => 'country',
              'tax_juris_name' => 'India',
              'tax_juris_code' => 'IN',
              'object' => 'line_item_tax',
              'line_item_id' => 'li_1mbDWbrRS1m8ql2PRG',
              'tax_amount' => 295,
              'is_partial_tax_applied' => false,
              'taxable_amount' => 5900,
              'is_non_compliance_tax' => false
            }],
            'currency_code' => 'USD',
            'round_off_amount' => 5,
            'line_item_discounts' => [{
              'object' => 'line_item_discount',
              'line_item_id' => 'li_1mbDWbrRS1m8ql2PRG',
              'discount_type' => 'item_level_coupon',
              'discount_amount' => 5900,
              'coupon_id' => '1FREEAGENT'
            }]
          },
         'credit_note_estimates' => [{
            'reference_invoice_id' =>  '133811',
            'type' =>  'refundable',
            'price_type' =>  'tax_exclusive',
            'sub_total' =>  0,
            'total' =>  0,
            'amount_allocated' =>  0,
            'amount_available' =>  0,
            'object' =>  'credit_note_estimate',
            'line_items' => [{
              'id' =>  'li_1mbDWbrRS1m8qX2PRB',
              'date_from' =>  1559284330,
              'date_to' =>  1575095388,
              'unit_amount' =>  35400,
              'quantity' =>  1,
              'amount' =>  35400,
              'pricing_model' =>  'per_unit',
              'is_taxed' =>  true,
              'tax_amount' =>  0,
              'tax_rate' =>  5.0,
              'object' =>  'line_item',
              'subscription_id' =>  '1',
              'description' =>  'Estate Half yearly plan - Prorated Credits for 31-May-2019 - 30-Nov-2019',
              'entity_type' =>  'plan',
              'entity_id' =>  'estate_jan_17_half_yearly',
              'discount_amount' =>  35400,
              'item_level_discount_amount' =>  35400
            }],
            'discounts' => [{
              'object' => 'discount',
              'entity_type' => 'item_level_coupon',
              'description' => '1 free agent',
              'amount' => 35400,
              'entity_id' => '1FREEAGENT'
            }],
            'taxes' => [{
              'object' => 'tax',
              'name' => 'IND TAX',
              'description' => 'IND TAX @ 5%',
              'amount' => 0
            }],
            'line_item_taxes' => [{
              'tax_name' => 'IND TAX',
              'tax_rate' => 5.0,
              'tax_juris_type' => 'country',
              'tax_juris_name' => 'India',
              'tax_juris_code' => 'IN',
              'object' => 'line_item_tax',
              'line_item_id' => 'li_1mbDWbrRS1m8qX2PRB',
              'tax_amount' => 0,
              'is_partial_tax_applied' => false,
              'taxable_amount' => 0,
              'is_non_compliance_tax' => false
            }],
           'currency_code' => 'USD',
           'round_off_amount' => 0,
           'line_item_discounts' => [{
              'object' => 'line_item_discount',
              'line_item_id' => 'li_1mbDWbrRS1m8qX2PRB',
              'discount_type' => 'item_level_coupon',
              'discount_amount' => 35400,
              'coupon_id' => '1FREEAGENT'
            }]
          },
          {
            'reference_invoice_id' => '133812',
            'type' => 'refundable',
            'price_type' => 'tax_exclusive',
            'sub_total' => 35400,
            'total' => 37200,
            'amount_allocated' => 0,
            'amount_available' => 37200,
            'object' => 'credit_note_estimate',
            'line_items' => [{
              'id' => 'li_1mbDWbrRS1m8qF2PR9',
              'date_from' => 1559284330,
              'date_to' => 1575095388,
              'unit_amount' => 35400,
              'quantity' => 1,
              'amount' => 35400,
              'pricing_model' => 'per_unit',
              'is_taxed' => true,
              'tax_amount' => 1770,
              'tax_rate' => 5.0,
              'object' => 'line_item',
              'subscription_id' => '1',
              'description' => 'Estate Half yearly plan - Prorated Credits for 31-May-2019 - 30-Nov-2019',
              'entity_type' => 'plan',
              'entity_id' => 'estate_jan_17_half_yearly',
              'discount_amount' => 0,
              'item_level_discount_amount' => 0
            }],
            'taxes' => [{
              'object' => 'tax',
              'name' => 'IND TAX',
              'description' => 'IND TAX @ 5%',
              'amount' => 1770
            }],
            'line_item_taxes' => [{
              'tax_name' => 'IND TAX',
              'tax_rate' => 5.0,
              'tax_juris_type' => 'country',
              'tax_juris_name' => 'India',
              'tax_juris_code' => 'IN',
              'object' => 'line_item_tax',
              'line_item_id' => 'li_1mbDWbrRS1m8qF2PR9',
              'tax_amount' => 1770,
              'is_partial_tax_applied' => false,
              'taxable_amount' => 35400,
              'is_non_compliance_tax' => false
            }],
            'currency_code' => 'USD',
            'round_off_amount' => 30,
            'line_item_discounts' => []
          }]
        }
      }
    end
end
