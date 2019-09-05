require_relative '../../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'agents_test_helper.rb')
require Rails.root.join('test', 'models', 'helpers', 'subscription_test_helper.rb')

class Admin::SubscriptionsControllerTest < ActionController::TestCase
  include AccountTestHelper
  include AgentsTestHelper
  include SubscriptionTestHelper
  
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

  def wrap_cname(params)
    params
  end
  
  def test_valid_show
    @account = Account.current
    get :show, construct_params(version: 'private')
    assert_response 200
    match_json(subscription_response(@account.subscription))
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

  def test_update_subscription
    create_new_account('test1', 'test1@freshdesk.com')
    update_currency
    @account.launch(:enable_customer_journey)
    stub_chargebee_methods
    stub_current_user
    @account.rollback :downgrade_policy
    # Testing upgrade from sprout/blossom to garden enables customer_journey feature
    assert !@account.features_list.include?(:customer_journey)
    put :update, construct_params({ version: 'private', plan_id: SubscriptionPlan.cached_current_plans.map(&:id).third, agent_seats: 1 }, {})
    @account.reload
    assert_response 200
    assert_equal JSON.parse(response.body)['plan_id'], SubscriptionPlan.cached_current_plans.map(&:id).third
    plan = @account.subscription.subscription_plan
    assert (::PLANS[:subscription_plans][plan.canon_name.to_sym][:features].dup - @account.features_list).empty?
    put :update, construct_params({ version: 'private', renewal_period: 6 }, {})
    assert_response 200
    #moving to sprout and checking all the validations
    put :update, construct_params({ version: 'private', plan_id: SubscriptionPlan.cached_current_plans.map(&:id).first, renewal_period: 6 }, {})
    assert_equal @account.subscription_plan.renewal_period, 1
    assert_response 200
    put :update, construct_params({ version: 'private', renewal_period: 6 }, {})
    assert_response 400
  ensure
    ChargeBee::Subscription.unstub(:update)
    User.unstub(:current)
    @controller.api_current_user.unstub(:privilege?)
  end

  def test_update_subscription_with_trial_state
    account = Account.current
    result = ChargeBee::Result.new(stub_update_params(account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    account.subscription.state = 'trial'
    put :update, construct_params({ version: 'private', plan_id: 8 }, {})
    assert_response 400
  ensure
    ChargeBee::Subscription.unstub(:update)
  end

  def test_update_subscription_with_suspended_state
    account = Account.current
    result = ChargeBee::Result.new(stub_update_params(account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    account.subscription.state = 'suspended'
    put :update, construct_params({ version: 'private', plan_id: 8 }, {})
    assert_response 402
  ensure
    ChargeBee::Subscription.unstub(:update)
  end

  def test_update_subscription_with_free_state
    account = Account.current
    result = ChargeBee::Result.new(stub_update_params(account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    account.subscription.state = 'free'
    put :update, construct_params({ version: 'private', plan_id: 8 }, {})
    assert_response 400
  ensure
    ChargeBee::Subscription.unstub(:update)
  end

  def test_update_susbcription_with_invalid_plan_id
    account = Account.current
    result = ChargeBee::Result.new(stub_update_params(account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    account.subscription.state = 'active'
    put :update, construct_params({ version: 'private', plan_id: '8' }, {})
    assert_response 400
  ensure
    ChargeBee::Subscription.unstub(:update) 
  end

  def test_update_subscription_with_invalid_renewal_period
    account = Account.current
    result = ChargeBee::Result.new(stub_update_params(account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    account.subscription.state = 'active'
    put :update, construct_params({ version: 'private', renewal_period: 20 }, {})
    assert_response 400
  ensure
    ChargeBee::Subscription.unstub(:update)
  end

  def test_update_subscription_with_no_card_number
    account = Account.current
    result = ChargeBee::Result.new(stub_update_params(account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    account.subscription.card_number = nil
    put :update, construct_params({ version: 'private', plan_id: 8 }, {})
    assert_response 400
  ensure
    ChargeBee::Subscription.unstub(:update)
  end

  def test_update_without_valid_plan_id
    account = Account.current
    result = ChargeBee::Result.new(stub_update_params(account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    account.subscription.state = 'active'
    account.subscription.card_number = '12345432'
    put :update, construct_params({ version: 'private', plan_id: Faker::Number.number(3) }, {})
    assert_response 400
  ensure
    ChargeBee::Subscription.unstub(:update)
  end

  def test_update_with_invalid_agent_seats
    account = Account.current
    result = ChargeBee::Result.new(stub_update_params(account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    account.subscription.state = 'active'
    account.subscription.card_number = '12345432'
    put :update, construct_params({ version: 'private', plan_id: 8 , agent_seats: '1' }, {})
    assert_response 400
  ensure
    ChargeBee::Subscription.unstub(:update)
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

  def test_update_subscription_downgrade_to_sprout
    @account = Account.find_by_full_domain('test1.freshpo.com').make_current
    plan_ids = SubscriptionPlan.current.map(&:id)
    stub_chargebee_methods
    stub_current_user
    params_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount != 0.0 }.compact.first
    params = { plan_id: params_plan_id }
    @account.subscription.card_number = '12345432'
    @account.subscription.update_attributes(agent_limit: '1')
    @account.subscription.update_attributes(subscription_plan_id: @account.subscription.subscription_plan_id)
    put :update, construct_params({ version: 'private' }.merge!(params.merge!(params_hash.except(:plan_id))), {})
    @account.reload
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_equal @account.subscription.subscription_plan_id, params_plan_id
    assert_response 200

    sprout_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount == 0.0 }.compact.first
    params = { plan_id: sprout_plan_id }
    @account.rollback :downgrade_policy
    put :update, construct_params({ version: 'private' }.merge!(params.merge!(params_hash.except(:plan_id, :renewal_period))), {})
    assert_equal @account.subscription.subscription_request.nil?, true
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, sprout_plan_id
    assert_response 200
  ensure
    unstub_chargebee_methods
    @account.destroy
  end

  private

    def stub_chargebee_requests
      chargebee_subscription = ChargeBee::Subscription.create({
        :plan_id => 'estate_jan_17_monthly',
        :billing_address => {
          :first_name => Faker::Name.first_name,
          :last_name => Faker::Name.last_name,
          :line1 => 'PO Box 9999',
          :city => 'Walnut',
          :state => 'California',
          :zip => '91789',
          :country => 'US'
        },
        :customer => {
          :first_name => Faker::Name.first_name,
          :last_name => Faker::Name.last_name,
          :email => Faker::Internet.email
        }
      })
      chargebee_estimate = ChargeBee::Estimate.create_subscription({
        :billing_address => {
          :line1 => 'PO Box 9999',
          :city => 'Walnut',
          :zip => '91789',
          :country => 'US'
        },
        :subscription => {
          :plan_id => 'estate_jan_17_monthly'
        }
      })
      Subscription.any_instance.stubs(:active?).returns(true)
      Billing::Subscription.any_instance.stubs(:calculate_update_subscription_estimate).returns(chargebee_estimate)
      ChargeBee::Subscription.stubs(:retrieve).returns(chargebee_subscription)
      RestClient::Request.stubs(:execute).returns(immediate_invoice_stub.to_json)
    end

    def unstub_chargebee_requests
      Subscription.any_instance.unstub(:active?)
      Billing::Subscription.any_instance.unstub(:calculate_update_subscription_estimate)
      ChargeBee::Subscription.unstub(:retrieve)
      RestClient::Request.unstub(:execute)
    end

    def params_hash
      {
        plan_id: SubscriptionPlan.current.map(&:id).third,
        renewal_period: SubscriptionPlan.current.third.renewal_period,
        agent_seats: 1
      }
    end

    def stub_current_user
      @account.subscription.card_number = '12345432'
      agent = @account.users.where(helpdesk_agent: true).first
      User.stubs(:current).returns(agent)
      @controller.stubs(:api_current_user).returns(User.current)
      @controller.api_current_user.stubs(:privilege?).returns(true)
    end

    def stub_chargebee_methods
      @account.launch :downgrade_policy
      Account.any_instance.stubs(:reseller_paid_account?).returns(true)
      Subscription.any_instance.stubs(:active?).returns(true)
      result = ChargeBee::Result.new(stub_update_params(@account.id))
      ChargeBee::Subscription.stubs(:update).returns(result)
    end

    def unstub_chargebee_methods
      User.unstub(:current)
      Account.any_instance.unstub(:reseller_paid_account?)
      @controller.api_current_user.unstub(:privilege?)
      Subscription.any_instance.unstub(:active?)
      ChargeBee::Subscription.unstub(:update)
      @account.rollback :downgrade_policy
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

    def subscription_response(subscription)
      {
        'id': subscription.id,
        'state': subscription.state,
        'plan_id': subscription.subscription_plan_id,
        'renewal_period': subscription.renewal_period,
        'next_renewal_at': subscription.next_renewal_at,
        'agent_seats': subscription.agent_limit,
        'card_number': subscription.card_number,
        'card_expiration': subscription.card_expiration,
        'name_on_card': (subscription.billing_address.name_on_card if subscription.billing_address.present?),
        'reseller_paid_account': subscription.reseller_paid_account?,
        'updated_at': %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
        'created_at': %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
        'currency': subscription.currency.name,
        'addons': nil
      
      }
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
