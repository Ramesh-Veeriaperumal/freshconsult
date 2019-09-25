require_relative '../../api/test_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'models', 'helpers', 'subscription_test_helper.rb')
class SubscriptionsControllerTest < ActionController::TestCase
  include AccountTestHelper
  include SubscriptionTestHelper
  include Redis::OthersRedis
  include Redis::Keys::Others

  def setup
    Subscription.any_instance.stubs(:chk_change_field_agents).returns(nil)
    Subscription.any_instance.stubs(:chk_change_agents).returns(nil)
    super
  end

  def teardown
    Subscription.any_instance.unstub(:chk_change_field_agents)
    Subscription.any_instance.unstub(:chk_change_agents)
  end

  def wrap_cname(params)
    params
  end

  def test_subscription_downgrade_to_sprout
    plan_ids = SubscriptionPlan.current.map(&:id)
    sprout_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount == 0.0 }.compact.first
    params = { plan_id: sprout_plan_id }
    stub_chargebee_requests
    @account.rollback :downgrade_policy
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    assert_equal @account.subscription.subscription_request.nil?, true
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, sprout_plan_id
    assert_response 302

    params_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount != 0.0 }.compact.first
    params = { plan_id: params_plan_id }
    @account.subscription.update_attributes(agent_limit: '1')
    @account.subscription.update_attributes(subscription_plan_id: @account.subscription.subscription_plan_id)
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    @account.reload
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_equal @account.subscription.subscription_plan_id, params_plan_id
    assert_response 302
  ensure
    unstub_chargebee_requests
  end

  def test_new_subscription_plan_change
    current_plan_id = @account.subscription.subscription_plan_id
    params_plan_id = SubscriptionPlan.current.map(&:id).second
    stub_chargebee_requests
    @account.subscription.update_attributes(agent_limit: '1')
    post :plan, construct_params({}, { agent_limit: '12', plan_id: params_plan_id }.merge!(params_hash.except(:plan_id, :agent_limit)))
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, params_plan_id
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_response 302
  ensure
    unstub_chargebee_requests
  end

  def test_same_plan_billing_cycle
    current_plan_id = @account.subscription.subscription_plan_id
    stub_chargebee_requests
    params = { agent_limit: '12', plan_id: current_plan_id, billing_cycle: SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual] }
    @account.subscription.update_attributes(agent_limit: '1')
    @account.subscription.update_attributes(renewal_period: 1)
    post :plan, construct_params({}, params.merge!(params_hash.except(:agent_limit, :plan_id, :billing_cycle)))
    @account.reload
    assert_equal @account.subscription.renewal_period, SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual]
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_response 302
  ensure
    unstub_chargebee_requests
  end

  def test_same_plan_billing_cycle_downgrade
    params = { plan_id: @account.subscription.subscription_plan_id, billing_cycle: SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:monthly] }
    stub_chargebee_requests
    @account.subscription.update_attributes(agent_limit: '1')
    @account.subscription.update_attributes(renewal_period: SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual])
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id, :billing_cycle)))
    @account.reload
    refute @account.subscription.renewal_period == SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:monthly]
    assert_equal @account.subscription.subscription_request.renewal_period, SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:monthly]
    assert_response 302
  ensure
    unstub_chargebee_requests
  end

  def test_same_plan_billing_cycle_downgrade_for_existing_customers
    params = { plan_id: @account.subscription.subscription_plan_id, billing_cycle: SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:monthly] }
    stub_chargebee_requests
    $redis_others.perform_redis_op('set', DOWNGRADE_POLICY_TO_ALL, true)
    @account.subscription.update_attributes(agent_limit: '1')
    @account.subscription.update_attributes(renewal_period: SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual])
    current_subscription = @account.subscription
    current_subscription.account.rollback :downgrade_policy
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id, :billing_cycle)))
    current_subscription.reload
    assert_equal current_subscription.account.launched?(:downgrade_policy), true
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_response 302
  ensure
    $redis_others.perform_redis_op('del', DOWNGRADE_POLICY_TO_ALL)
    unstub_chargebee_requests
  end

  def test_same_plan_agent_limit
    params = { plan_id: @account.subscription.subscription_plan_id, agent_limit: '6' }
    stub_chargebee_requests
    @account.subscription.update_attributes(agent_limit: '1')
    post :plan, construct_params({}, params.merge!(params_hash.except(:agent_limit, :plan_id)))
    @account.reload
    assert_equal @account.subscription.agent_limit, 6
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_response 302
  ensure
    unstub_chargebee_requests
  end

  def test_same_plan_agent_limit_downgrade
    params = { plan_id: @account.subscription.subscription_plan_id, agent_limit: '1' }
    stub_chargebee_requests
    @account.subscription.update_attributes(agent_limit: '6')
    post :plan, construct_params({}, params.merge!(params_hash.except(:agent_limit, :plan_id)))
    @account.reload
    assert_equal @account.subscription.agent_limit, 6
    assert_equal @account.subscription.subscription_request.agent_limit, 1
    assert_response 302
  ensure
    unstub_chargebee_requests
  end

  def test_same_plan_enable_fsm
    params = { agent_limit: '1', addons: { field_service_management: { enabled: 'true', value: ' ' } } }
    stub_chargebee_requests
    @account.subscription.update_attributes(agent_limit: '6')
    post :plan, construct_params({}, params.merge!(params_hash.except(:agent_limit)))
    @account.reload
    assert_equal @account.subscription.additional_info[:field_agent_limit], nil
    assert_response 302
  ensure
    unstub_chargebee_requests
  end

  def test_same_plan_disable_fsm
    params = { agent_limit: '1', addons: { field_service_management: { enabled: 'false' } } }
    stub_chargebee_requests
    @account.subscription.update_attributes(agent_limit: '6')
    post :plan, construct_params({}, params.merge!(params_hash.except(:agent_limit)))
    @account.reload
    assert_equal @account.subscription.subscription_request.fsm_field_agents, nil
    assert_response 302
  ensure
    unstub_chargebee_requests
  end

  def test_same_plan_fsm_agent_seats_decrease
    params = { agent_limit: '1', addons: { field_service_management: { enabled: 'true', value: '1' } } }
    stub_chargebee_requests
    @account.subscription.update_attributes(agent_limit: '6')
    @account.subscription.update_attributes(additional_info: { field_agent_limit: 3 })
    post :plan, construct_params({}, params.merge!(params_hash.except(:agent_limit)))
    @account.reload
    assert_equal @account.subscription.additional_info[:field_agent_limit], 3
    assert_equal @account.subscription.subscription_request.fsm_field_agents, 1
    assert_response 302
  ensure
    unstub_chargebee_requests
  end

  def test_plan_change_without_lp
    current_plan_id = @account.subscription.subscription_plan_id
    stub_chargebee_requests
    @account.rollback(:downgrade_policy)
    post :plan, construct_params({ plan_id: current_plan_id - 1 }.merge!(params_hash.except(:plan_id)))
    @account.reload
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_response 302
  ensure
    unstub_chargebee_requests
  end

  def test_show_for_online_payments
    Account.stubs(:current).returns(Account.first)
    Subscription.any_instance.stubs(:active?).returns(true)
    Subscription.any_instance.stubs(:offline_subscription?).returns(true)
    get :show
    assert_response 200
  ensure
    Account.unstub(:current)
    Subscription.any_instance.unstub(:active?)
    Subscription.any_instance.unstub(:offline_subscription?)
  end

  def test_cancel_request_with_no_scheduled_requests
    @account = Account.current
    ChargeBee::Subscription.stubs(:remove_scheduled_changes).returns(true)
    @account.subscription.subscription_request.destroy if @account.subscription.subscription_request.present?
    delete :cancel_request
    assert_response 404
  ensure
    ChargeBee::Subscription.unstub(:remove_scheduled_changes)
  end

  def test_cancel_request_when_chargebee_succeeds
    @account = Account.current
    create_subscription_request(@account)
    ChargeBee::Subscription.stubs(:remove_scheduled_changes).returns(true)
    delete :cancel_request
    assert_response 204
  ensure
    @account.subscription.subscription_request.destroy if @account.subscription.subscription_request.present?
    ChargeBee::Subscription.unstub(:remove_scheduled_changes)
  end

  def test_cancel_request_when_chargebee_throws_exception
    @account = Account.current
    create_subscription_request(@account)
    ChargeBee::Subscription.stubs(:remove_scheduled_changes).raises(ChargeBee::InvalidRequestError.new "dummy error", {message: "dummy message", error_code: "dummy error code"})
    assert_raise(ChargeBee::InvalidRequestError) { delete :cancel_request }
  ensure
    @account.subscription.subscription_request.destroy if @account.subscription.subscription_request.present?
    ChargeBee::Subscription.unstub(:remove_scheduled_changes)
  end

  def test_cancel_request_when_chargebee_has_no_scheduled_request
    @account = Account.current
    create_subscription_request(@account)
    ChargeBee::Subscription.stubs(:remove_scheduled_changes).raises(ChargeBee::InvalidRequestError.new "dummy error", {message: "dummy message", error_code: "no_scheduled_changes"})
    delete :cancel_request
    assert_response 204
  ensure
    @account.subscription.subscription_request.destroy if @account.subscription.subscription_request.present?
    ChargeBee::Subscription.unstub(:remove_scheduled_changes)
  end

  def test_cancel_request_when_destroy_fails
    @account = Account.current
    create_subscription_request(@account)
    ChargeBee::Subscription.stubs(:remove_scheduled_changes).returns(true)
    SubscriptionRequest.any_instance.stubs(:destroy).returns(false)
    delete :cancel_request
    assert_response 404
  ensure
    @account.subscription.subscription_request.destroy if @account.subscription.subscription_request.present?
    ChargeBee::Subscription.unstub(:remove_scheduled_changes)
  end

  def test_cancel_account_cancellation_request
    @account.launch(:downgrade_policy)
    set_others_redis_key(@account.account_cancellation_request_time_key, Time.zone.now)
    ChargeBee::Subscription.stubs(:remove_scheduled_cancellation).returns(true)
    delete :cancel_request
    assert_response 204
  ensure
    @account.rollback(:downgrade_policy)
    ChargeBee::Subscription.unstub(:remove_scheduled_cancellation)
  end

  def test_cancel_request_when_account_cancellation_not_requested
    delete :cancel_request
    assert_response 404
  end

  def test_cancel_account_cancellation_request_errors_in_exception
    @account.launch(:downgrade_policy)
    set_others_redis_key(@account.account_cancellation_request_time_key, Time.zone.now)
    ChargeBee::Subscription.stubs(:remove_scheduled_cancellation).raises(ChargeBee::InvalidRequestError)
    delete :cancel_request
    assert_response 404
  end

  private

    def params_hash
      plan_id = @account.subscription.subscription_plan_id
      {
        currency: 'USD',
        plan_id: plan_id,
        billing_cycle: @account.subscription.renewal_period,
        agent_limit: '1'
      }
    end

    def stub_chargebee_requests
      create_new_account('test1', 'test1@freshdesk.com')
      update_currency
      Account.stubs(:current).returns(@account)
      @account.launch :downgrade_policy
      @account.launch(:addon_based_billing)
      chargebee_update = ChargeBee::Result.new(stub_update_params(@account.id))
      ChargeBee::Subscription.stubs(:update).returns(chargebee_update)
      chargebee_estimate = ChargeBee::Result.new(stub_estimate_params)
      ChargeBee::Estimate.stubs(:update_subscription).returns(chargebee_estimate)
      chargebee_coupon = ChargeBee::Result.new(stub_chargebee_coupon)
      ChargeBee::Coupon.stubs(:retrieve).returns(chargebee_coupon)
      chargebee_plan = ChargeBee::Result.new(stub_chargebee_plan)
      ChargeBee::Plan.stubs(:retrieve).returns(chargebee_plan)
      ChargeBee::Subscription.stubs(:retrieve).returns(chargebee_update)
      Subscription.any_instance.stubs(:active?).returns(true)
      @controller.stubs(:set_current_account).returns(@account)
      @controller.stubs(:request_host).returns('test1.freshpo.com')
    end

    def unstub_chargebee_requests
      ChargeBee::Subscription.unstub(:update)
      ChargeBee::Estimate.unstub(:update_subscription)
      ChargeBee::Subscription.unstub(:retrieve)
      ChargeBee::Plan.unstub(:retrieve)
      ChargeBee::Coupon.unstub(:retrieve)
      Subscription.any_instance.unstub(:active?)
      @controller.unstub(:set_current_account)
      @controller.unstub(:request_host)
      @account.destroy
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

  def create_subscription_request(account)
    if account.subscription.subscription_request.blank?
      t = SubscriptionRequest.new(
        account_id: account.id,
        agent_limit: 1,
        plan_id: SubscriptionPlan.current.map(&:id).third,
        renewal_period: 1,
        subscription_id: account.subscription.id
      )
      t.save!
    end
  end
end
