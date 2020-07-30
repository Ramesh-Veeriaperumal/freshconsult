require_relative '../../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'agents_test_helper.rb')
require Rails.root.join('test', 'models', 'helpers', 'subscription_test_helper.rb')

class Admin::SubscriptionsControllerTest < ActionController::TestCase
  include AccountTestHelper
  include AgentsTestHelper
  include SubscriptionTestHelper
  include Redis::OthersRedis
  include Redis::Keys::Others

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
    @account ||= create_test_account
    @account.subscription.update_attributes(agent_limit: 10) if @account.subscription.agent_limit.blank?
    unless Account.current.subscription.active?
      subscription = Account.current.subscription
      subscription.state = 'active'
      subscription.save!
    end
  end

  def wrap_cname(params)
    params
  end

  def teardown
    PLANS[:subscription_plans][:forest_jan_19][:features].map { |feature| @account.add_feature(feature) }
  end

  def test_show_with_subscription_request
    subscription_request = @account.subscription.subscription_request
    subscription = @account.subscription
    subscription_request.destroy if subscription_request.present?
    subscription_request_params = {
      agent_limit: 1,
      plan_id: @account.subscription.subscription_plan_id,
      renewal_period: 1,
      subscription_id: @account.subscription.id,
      fsm_field_agents: nil
    }
    Subscription.any_instance.stubs(:cost_per_agent).returns(65)
    Subscription.any_instance.stubs(:cost_per_agent).with(12).returns(49)
    @account.subscription.build_subscription_request(subscription_request_params).save!
    new_subscription_request = @account.subscription_request
    subscription_request_params[:feature_loss] = new_subscription_request.feature_loss?
    subscription_request_params[:products_limit_exceeded] = new_subscription_request.product_loss?
    get :show, controller_params(version: 'private')
    assert_response 200
    match_json(subscription_response(@account.subscription, subscription_request_params))
  ensure
    @account.subscription.subscription_request.destroy if @account.subscription.subscription_request.present?
    Subscription.any_instance.unstub(:cost_per_agent)
  end

  def test_show_without_subscription_request
    subscription_request = @account.subscription.subscription_request
    Subscription.any_instance.stubs(:cost_per_agent).returns(65)
    Subscription.any_instance.stubs(:cost_per_agent).with(12).returns(49)
    subscription_request.destroy if subscription_request.present?
    get :show, controller_params(version: 'private')
    assert_response 200
    match_json(subscription_response(@account.subscription))
  ensure
      Subscription.any_instance.unstub(:cost_per_agent)
  end

  def test_show_no_privilege
    stub_admin_tasks_privilege
    get :show, controller_params(version: 'private')
    assert_response 403
    unstub_privilege
  end

  def test_show_with_valid_sideload_options
    Subscription.any_instance.stubs(:fetch_update_payment_site).returns(url: Faker::Internet.url, site: Faker::Internet.url)
    get :show, controller_params(version: 'private', include: 'update_payment_site')
    assert_response 200
    match_json(subscription_response(@account.subscription, nil, true))
  ensure
    Subscription.any_instance.unstub(:fetch_update_payment_site)
  end

  def test_show_with_invalid_sideload_options
    get :show, controller_params(version: 'private', include: Faker::Lorem.word)
    assert_response 400
    match_json([bad_request_error_pattern('include', :not_included, code: 'invalid_value', list: ['update_payment_site'])])
  end

  def test_show_with_invalid_parameters
    key = Faker::Lorem.word
    get :show, controller_params(version: 'private', key: key)
    assert_response 400
    match_json([bad_request_error_pattern('key', :invalid_field)])
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

  def test_update_subscription_without_downgrade_policy
    update_currency
    stub_methods
    Subscription.any_instance.stubs(:cost_per_agent).returns(65)
    Subscription.any_instance.stubs(:cost_per_agent).with(12).returns(49)
    @account.launch :unlimited_multi_product
    @account.rollback :downgrade_policy
    plan_id = (SubscriptionPlan.cached_current_plans.map(&:id) - [@account.subscription.subscription_plan_id]).last
    put :update, construct_params(version: 'private', plan_id: plan_id, agent_seats: @account.full_time_support_agents.count + 1)
    assert_equal 200, response.response_code, "1st #{response.body.inspect}"
    assert_equal JSON.parse(response.body)['plan_id'], plan_id
    plan = @account.subscription.subscription_plan
    assert (::PLANS[:subscription_plans][plan.canon_name.to_sym][:features].dup - @account.features_list).empty?
    put :update, construct_params(version: 'private', renewal_period: 6)
    assert_equal 200, response.response_code, "2nd #{response.body.inspect}"
    # moving to sprout and checking all the validations
    put :update, construct_params(version: 'private', plan_id: sprout_plan_id, renewal_period: 6)
    assert_equal @account.subscription_plan.renewal_period, 1
    assert_equal 200, response.response_code, "3rd #{response.body.inspect}"
  ensure
    unstub_methods
    Subscription.any_instance.unstub(:cost_per_agent)
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
    Subscription.any_instance.stubs(:card_number).returns(nil)
    put :update, construct_params({ version: 'private', plan_id: 8 }, {})
    assert_response 400
  ensure
    Subscription.any_instance.unstub(:card_number)
    ChargeBee::Subscription.unstub(:update)
  end

  def test_update_without_valid_plan_id
    account = Account.current
    result = ChargeBee::Result.new(stub_update_params(account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    account.subscription.state = 'active'
    put :update, construct_params({ version: 'private', plan_id: Faker::Number.number(3) }, {})
    assert_response 400
  ensure
    ChargeBee::Subscription.unstub(:update)
  end

  def test_update_with_invalid_agent_seats
    account = Account.current
    result = ChargeBee::Result.new(stub_update_params(account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    Subscription.any_instance.stubs(:active?).returns(true)
    Subscription.any_instance.stubs(:card_number).returns(true)
    put :update, construct_params({ version: 'private', plan_id: 8 , agent_seats: '1' }, {})
    assert_response 400
  ensure
    Subscription.any_instance.unstub(:active?)
    Subscription.any_instance.unstub(:card_number)
    ChargeBee::Subscription.unstub(:update)
  end

  def test_update_with_currency_change_on_active_plan
    account = Account.current
    result = ChargeBee::Result.new(stub_update_params(account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    Subscription.any_instance.stubs(:state).returns('active')
    put :update, construct_params(version: 'private', currency: 'INR')
    assert_response 400
    match_json([bad_request_error_pattern('currency', :cannot_update_currency_unless_free_plan, code: :invalid_value, account_state: 'active')])
  ensure
    ChargeBee::Subscription.unstub(:update)
    Subscription.any_instance.unstub(:state)
  end

  def test_update_with_currency_change_on_free_plan
    account = Account.current
    result = ChargeBee::Result.new(stub_update_params(account.id))
    Billing::Subscription.any_instance.stubs(:retrieve_subscription).returns(result)
    Billing::Subscription.any_instance.stubs(:cancel_subscription).returns(true)
    Billing::Subscription.any_instance.stubs(:subscription_exists?).returns(true)
    Billing::Subscription.any_instance.stubs(:reactivate_subscription).returns(true)
    ChargeBee::Subscription.stubs(:update).returns(result)
    Subscription.any_instance.stubs(:state).returns('free')
    Subscription.any_instance.stubs(:non_new_sprout?).returns(false)
    put :update, construct_params(version: 'private', currency: 'INR')
    assert_response 200
    assert_equal account.subscription.reload.currency.name, 'INR'
  ensure
    Billing::Subscription.any_instance.unstub(:retrieve_subscription)
    Billing::Subscription.any_instance.unstub(:cancel_subscription)
    Billing::Subscription.any_instance.unstub(:subscription_exists?)
    Billing::Subscription.any_instance.unstub(:reactivate_subscription)
    ChargeBee::Subscription.unstub(:update)
    Subscription.any_instance.unstub(:non_new_sprout?)
    Subscription.any_instance.unstub(:state)
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
    stub_methods
    if @account.subscription.subscription_plan_id == sprout_plan_id
      subscription = @account.subscription
      subscription.plan = SubscriptionPlan.current.where("id != #{sprout_plan_id}").first
      subscription.save!
    end
    Subscription.any_instance.stubs(:coupon).returns(nil)
    params = { version: 'private', plan_id: sprout_plan_id, renewal_period: 12, agent_seats: 1 }
    @account.subscription.subscription_request.destroy if @account.subscription.subscription_request.present?
    @account.rollback :downgrade_policy
    put :update, construct_params(params)
    assert_equal 200, response.response_code, "1st #{response.body.inspect}"
    params.delete(:renewal_period)
    match_json(update_response(params, @account.subscription))
  ensure
    Subscription.unstub(:coupon)
    unstub_methods
  end

  def test_update_subscription_renewal_period_for_existing_customers
    plan_ids = SubscriptionPlan.current.map(&:id)
    stub_methods
    Subscription.any_instance.stubs(:cost_per_agent).returns(65)
    Subscription.any_instance.stubs(:cost_per_agent).with(12).returns(49)
    params_plan_id = (paid_plans - [@account.subscription.subscription_plan_id]).first
    renewal_period = (SubscriptionPlan::BILLING_CYCLE_NAMES_BY_KEY.keys - [@account.subscription.renewal_period]).first
    params = { plan_id: params_plan_id, renewal_period: renewal_period, version: 'private' }
    current_subscription = @account.subscription
    current_subscription.subscription_request.destroy if current_subscription.subscription_request.present?
    @account.rollback :downgrade_policy
    put :update, construct_params(params)
    assert_equal 200, response.response_code, "1st #{response.body.inspect}"
    assert_equal current_subscription.account.launched?(:downgrade_policy), true
    match_json(update_response(params, @account.subscription))
  ensure
    unstub_methods
    Subscription.any_instance.unstub(:cost_per_agent)
  end

  def test_update_payment
    Subscription.any_instance.stubs(:cost_per_agent).returns(65)
    chargebee_subscription = ChargeBee::Result.new(stub_update_params(@account.id))
    Billing::Subscription.any_instance.stubs(:activate_subscription).returns(chargebee_subscription)
    Billing::Subscription.any_instance.stubs(:retrieve_subscription).returns(chargebee_subscription)
    Subscription.any_instance.stubs(:set_billing_info).returns(true)
    Subscription.any_instance.stubs(:save).returns(true)
    post :update_payment, construct_params(agent_limit: Faker::Number.number(2))
    assert_response 200
    match_json(subscription_response(@account.subscription))
  ensure
    Billing::Subscription.any_instance.unstub(:retrieve_subscription)
    Billing::Subscription.any_instance.unstub(:activate_subscription)
    Subscription.any_instance.unstub(:set_billing_info)
    Subscription.any_instance.unstub(:save)
    Subscription.any_instance.unstub(:cost_per_agent)
  end

  def test_update_payment_error_out
    Billing::Subscription.any_instance.stubs(:retrieve_subscription).raises(ChargeBee::InvalidRequestError)
    post :update_payment, construct_params(agent_limit: Faker::Number.number(2))
    assert_response 400
  ensure
    Billing::Subscription.any_instance.unstub(:retrieve_subscription)
  end

  def test_estimate_feature_loss
    Account.stubs(:current).returns(Account.first)
    current_features = Account.current.features_list.push(:sla_management)
    Account.any_instance.stubs(:features_list).returns(current_features)
    plan = SubscriptionPlan.cached_current_plans.find { |p| p.display_name = 'Blossom' }
    get :estimate_feature_loss, controller_params({ version: 'private', plan_id: plan.id }, false)
    assert_response 200
    payload = JSON.parse(response.body)
    assert_includes payload['features'], 'sla_management'
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:features_list)
  end

  def test_estimate_feature_loss_invalid_request
    Account.stubs(:current).returns(Account.first)
    current_features = Account.current.features_list.push(:sla_management)
    Account.any_instance.stubs(:features_list).returns(current_features)
    plan = SubscriptionPlan.cached_current_plans.find { |p| p.display_name = 'Blossom' }
    get :estimate_feature_loss, controller_params({ version: 'private', plan_name: plan.id }, false)
    assert_response 400
  ensure
    Account.unstub(:current)
    Account.any_instance.unstub(:features_list)
  end

  def test_estimate_feature_loss_invalid_plan
    account = Account.current
    result = ChargeBee::Result.new(stub_update_params(account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    account.subscription.state = 'active'
    put :estimate_feature_loss, construct_params({ version: 'private', plan_id: Faker::Number.number(3) }, {})
    assert_response 400
  ensure
    ChargeBee::Subscription.unstub(:update)
  end

  def test_update_with_lesser_agent_seats
    account = Account.current
    result = ChargeBee::Result.new(stub_update_params(account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    Subscription.any_instance.stubs(:active?).returns(true)
    Subscription.any_instance.stubs(:card_number).returns(true)
    Subscription.any_instance.stubs(:downgrade?).returns(false)
    Account.any_instance.stubs(:full_time_support_agents).returns([1, 2, 3, 4, 5])
    plan = SubscriptionPlan.cached_current_plans.find { |p| p.display_name == 'Blossom' }
    put :update, construct_params({ version: 'private', plan_id: plan.id, agent_seats: 1 }, {})
    assert_response 400
  ensure
    Subscription.any_instance.unstub(:active?)
    Subscription.any_instance.unstub(:card_number)
    ChargeBee::Subscription.unstub(:update)
    Account.any_instance.unstub(:full_time_support_agents)
  end

  private

    def sprout_plan_id
      @sprout_plan_id ||= SubscriptionPlan.current.where('amount = 0').compact.first.id
    end

    def paid_plans
      @paid_plans ||= SubscriptionPlan.current.where('amount != 0').pluck(:id)
    end

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

    def stub_methods
      @account.launch :downgrade_policy
      Account.any_instance.stubs(:reseller_paid_account?).returns(true)
      Subscription.any_instance.stubs(:active?).returns(true)
      Subscription.any_instance.stubs(:card_number).returns('12767526')
      result = ChargeBee::Result.new(stub_update_params(@account.id))
      ChargeBee::Subscription.stubs(:update).returns(result)
      admin_user = @account.technicians.find{ |x| x.privilege?(:admin_tasks) }
      User.stubs(:current).returns(admin_user)
      User.any_instance.stubs(:privilege?).returns(true)
    end

    def unstub_methods
      User.unstub(:current)
      Account.any_instance.unstub(:reseller_paid_account?)
      unstub_privilege
      Subscription.any_instance.unstub(:active?)
      Subscription.any_instance.unstub(:card_number)
      ChargeBee::Subscription.unstub(:update)
      @account.rollback :downgrade_policy
      @controller.unstub(:api_current_user)
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

    def update_response(params, subscription)
      {
        id: subscription.id,
        state: subscription.state,
        plan_id: params[:plan_id],
        renewal_period: params[:renewal_period] || subscription.renewal_period,
        next_renewal_at: subscription.next_renewal_at,
        days_remaining: (subscription.next_renewal_at.utc.to_date - DateTime.now.utc.to_date).to_i,
        agent_seats: params[:agent_limit] || subscription.agent_limit,
        card_number: subscription.card_number,
        card_expiration: subscription.card_expiration,
        name_on_card: (subscription.billing_address.name_on_card if subscription.billing_address.present?),
        reseller_paid_account: subscription.reseller_paid_account?,
        switch_to_annual_percentage: subscription.percentage_difference,
        subscription_request: nil,
        updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
        created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
        currency: subscription.currency.name,
        addons: nil,
        paying_account: subscription.paying_account?,
        update_payment_site: nil,
        features_gained: subscription.additional_info[:feature_gain],
        discount: subscription.additional_info[:discount],
        offline: subscription.offline_subscription?
      }
    end

    def subscription_response(subscription, subscription_request_params = nil, is_sideload_present = false)
      response_hash = {
        id: subscription.id,
        state: subscription.state,
        plan_id: subscription.subscription_plan_id,
        renewal_period: subscription.renewal_period,
        next_renewal_at: subscription.next_renewal_at,
        days_remaining: (subscription.next_renewal_at.utc.to_date - DateTime.now.utc.to_date).to_i,
        agent_seats: subscription.agent_limit,
        card_number: subscription.card_number,
        card_expiration: subscription.card_expiration,
        name_on_card: (subscription.billing_address.name_on_card if subscription.billing_address.present?),
        reseller_paid_account: subscription.reseller_paid_account?,
        switch_to_annual_percentage: subscription.percentage_difference,
        updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
        created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
        currency: subscription.currency.name,
        addons: nil,
        subscription_request: nil,
        paying_account: subscription.paying_account?,
        features_gained: subscription.account.account_additional_settings.additional_settings[:feature_gain],
        discount: subscription.account.account_additional_settings.additional_settings[:discount],
        offline: subscription.offline_subscription?
      }
      response_hash[:update_payment_site] = is_sideload_present ? subscription.fetch_update_payment_site : nil
      if subscription_request_params.present?
        subscription_plan = SubscriptionPlan.find(subscription_request_params[:plan_id])
        request_hash = {}.tap do |hash|
          hash['plan_name'] = subscription_plan.name
          hash['feature_loss'] = subscription_request_params[:feature_loss]
          hash['products_limit_exceeded'] = subscription_request_params[:products_limit_exceeded]
          unless subscription_plan.amount.zero?
            hash['agent_seats'] = subscription_request_params[:agent_limit]
            hash['renewal_period'] = subscription_request_params[:renewal_period]
            hash['fsm_field_agents'] = subscription_request_params[:fsm_field_agents]
          end
        end
        response_hash.merge!(subscription_request: request_hash)
      end
      response_hash
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
