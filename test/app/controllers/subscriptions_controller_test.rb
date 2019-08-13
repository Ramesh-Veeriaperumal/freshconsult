require_relative '../../api/test_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
class SubscriptionsControllerTest < ActionController::TestCase
  include AccountTestHelper

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

  def test_move_plan_from_sprout
    current_plan_id = SubscriptionPlan.cached_current_plans.map(&:id).first
    params_plan_id = SubscriptionPlan.cached_current_plans.map(&:id).third
    create_new_account('test9', 'test9@freshdesk.com')
    update_currency
    Account.stubs(:current).returns(@account)
    params = { plan_id: params_plan_id }
    @account.launch :downgrade_policy
    @account.launch(:addon_based_billing)
    result = ChargeBee::Result.new(stub_update_params(@account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    ChargeBee::Subscription.stubs(:retrieve).returns(result)
    Subscription.any_instance.stubs(:active?).returns(true)
    Subscription.any_instance.stubs(:total_amount).returns(0)
    @account.subscription.update_attributes(agent_limit: '1')
    @account.subscription.update_attributes(subscription_plan_id: current_plan_id)
    @controller.stubs(:load_coupon).returns(nil)
    @controller.stubs(:set_current_account).returns(@account)
    @controller.stubs(:request_host).returns('test9.freshpo.com')

    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    @account.reload
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_equal @account.subscription.subscription_plan_id, params_plan_id
    assert_response 302
  ensure
    ChargeBee::Subscription.unstub(:update)
    ChargeBee::Subscription.unstub(:retrieve)
    Subscription.any_instance.unstub(:active?)
    @account.destroy
  end

  def test_new_subscription_plan_change
    current_plan_id = SubscriptionPlan.current.map(&:id).third
    params_plan_id = SubscriptionPlan.current.map(&:id).second
    create_sample_account('test1', 'test1@freshdesk.com')
    Account.stubs(:current).returns(@account)
    @account.launch(:downgrade_policy)
    @account.launch(:addon_based_billing)
    result = ChargeBee::Result.new(stub_update_params(@account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    ChargeBee::Subscription.stubs(:retrieve).returns(result)
    Subscription.any_instance.stubs(:active?).returns(true)
    Subscription.any_instance.stubs(:total_amount).returns(0)
    @account.subscription.update_attributes(subscription_plan_id: current_plan_id)
    @account.subscription.update_attributes(agent_limit: '1')
    @controller.stubs(:load_coupon).returns(nil)
    @controller.stubs(:set_current_account).returns(@account)
    @controller.stubs(:request_host).returns('test1.freshpo.com')
    
    post :plan, construct_params({}, { agent_limit: '12', plan_id: params_plan_id }.merge!(params_hash.except(:plan_id, :agent_limit)))
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, current_plan_id
    assert_equal @account.subscription.subscription_request.plan_id, params_plan_id
    assert_response 302
  ensure
    ChargeBee::Subscription.unstub(:update)
    ChargeBee::Subscription.unstub(:retrieve)
    Subscription.any_instance.unstub(:active?)
    @account.destroy
  end

  def test_same_plan_billing_cycle_fixed
    current_plan_id = SubscriptionPlan.current.map(&:id).third
    params_plan_id = SubscriptionPlan.current.map(&:id).third
    create_sample_account('test2', 'test2@freshdesk.com')
    Account.stubs(:current).returns(@account)
    params =  { agent_limit: '12', plan_id: params_plan_id, billing_cycle: SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual] }
    @account.launch(:downgrade_policy)
    @account.launch(:addon_based_billing)
    result = ChargeBee::Result.new(stub_update_params(@account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    ChargeBee::Subscription.stubs(:retrieve).returns(result)
    Subscription.any_instance.stubs(:active?).returns(true)
    Subscription.any_instance.stubs(:total_amount).returns(0)
    @account.subscription.update_attributes(agent_limit: '1')
    @account.subscription.update_attributes(renewal_period: 1)
    @account.subscription.update_attributes(subscription_plan_id: current_plan_id)
    
    @controller.stubs(:load_coupon).returns(nil)
    @controller.stubs(:set_current_account).returns(@account)
    @controller.stubs(:request_host).returns('test2.freshpo.com')

    post :plan, construct_params({}, params.merge!(params_hash.except(:agent_limit, :plan_id, :billing_cycle)))
    @account.reload
    assert_equal @account.subscription.renewal_period, SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual]
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_response 302
  ensure
    ChargeBee::Subscription.unstub(:update)
    ChargeBee::Subscription.unstub(:retrieve)
    Subscription.any_instance.unstub(:active?)
    @account.destroy
  end

  def test_same_plan_billing_cycle_downgrade_fixed
    params =  { plan_id: SubscriptionPlan.current.map(&:id).third, billing_cycle: SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:monthly] }
    create_sample_account('test3', 'test3@freshdesk.com')
    Account.stubs(:current).returns(@account)
    @account.launch(:downgrade_policy)
    @account.launch(:addon_based_billing)
    result = ChargeBee::Result.new(stub_update_params(@account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    ChargeBee::Subscription.stubs(:retrieve).returns(result)
    Subscription.any_instance.stubs(:active?).returns(true)
    Subscription.any_instance.stubs(:total_amount).returns(0)
    @account.subscription.update_attributes(agent_limit: '1')
    @account.subscription.update_attributes(renewal_period: SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual])
    @account.subscription.update_attributes(subscription_plan_id: SubscriptionPlan.current.map(&:id).third)    
    @controller.stubs(:load_coupon).returns(nil)
    @controller.stubs(:set_current_account).returns(@account)
    @controller.stubs(:request_host).returns('test3.freshpo.com')

    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id, :billing_cycle)))
    @account.reload
    refute @account.subscription.renewal_period == SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:monthly]
    assert_equal @account.subscription.subscription_request.renewal_period, SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:monthly]
    assert_response 302
  ensure
    ChargeBee::Subscription.unstub(:update)
    ChargeBee::Subscription.unstub(:retrieve)
    Subscription.any_instance.unstub(:active?)
    @account.destroy
  end

  def test_same_plan_agent_limit
    create_sample_account('test4', 'test4@freshdesk.com')
    Account.stubs(:current).returns(@account)
    params =  { plan_id: SubscriptionPlan.current.map(&:id).third, agent_limit: '6' }
    @account.launch(:downgrade_policy)
    @account.launch(:addon_based_billing)
    result = ChargeBee::Result.new(stub_update_params(@account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    ChargeBee::Subscription.stubs(:retrieve).returns(result)
    Subscription.any_instance.stubs(:active?).returns(true)
    Subscription.any_instance.stubs(:total_amount).returns(0)
    @account.subscription.update_attributes(agent_limit: '1')
    @account.subscription.update_attributes(subscription_plan_id: SubscriptionPlan.current.map(&:id).third)
    @controller.stubs(:load_coupon).returns(nil)
    @controller.stubs(:set_current_account).returns(@account)
    @controller.stubs(:request_host).returns('test4.freshpo.com')

    post :plan, construct_params({}, params.merge!(params_hash.except(:agent_limit, :plan_id)))
    @account.reload
    assert_equal @account.subscription.agent_limit, 6
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_response 302
  ensure
    ChargeBee::Subscription.unstub(:update)
    ChargeBee::Subscription.unstub(:retrieve)
    Subscription.any_instance.unstub(:active?)
    @account.destroy
  end

  def test_same_plan_agent_limit_downgrade
    params =  { plan_id: SubscriptionPlan.current.map(&:id).third, agent_limit: '1' }
    create_sample_account('test5', 'test5@freshdesk.com')
    Account.stubs(:current).returns(@account)
    @account.launch(:downgrade_policy)
    @account.launch(:addon_based_billing)
    result = ChargeBee::Result.new(stub_update_params(@account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    ChargeBee::Subscription.stubs(:retrieve).returns(result)
    Subscription.any_instance.stubs(:active?).returns(true)
    Subscription.any_instance.stubs(:total_amount).returns(0)
    @account.subscription.update_attributes(agent_limit: '6')
    @account.subscription.update_attributes(subscription_plan_id: SubscriptionPlan.current.map(&:id).third)
    @controller.stubs(:load_coupon).returns(nil)
    @controller.stubs(:set_current_account).returns(@account)
    @controller.stubs(:request_host).returns('test5.freshpo.com')
    
    post :plan, construct_params({}, params.merge!(params_hash.except(:agent_limit, :plan_id)))
    @account.reload
    assert_equal @account.subscription.agent_limit, 6
    assert_equal @account.subscription.subscription_request.agent_limit, 1
    assert_response 302
  ensure
    ChargeBee::Subscription.unstub(:update)
    ChargeBee::Subscription.unstub(:retrieve)
    Subscription.any_instance.unstub(:active?)
    @account.destroy
  end

  def test_same_plan_enable_fsm
    create_sample_account('test6', 'test6@freshdesk.com')
    Account.stubs(:current).returns(@account)
    params = { agent_limit: '1', addons: { field_service_management: { enabled: 'true', value: ' ' } } }
    @account.launch(:downgrade_policy)
    @account.launch(:addon_based_billing)
    result = ChargeBee::Result.new(stub_update_params(@account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    ChargeBee::Subscription.stubs(:retrieve).returns(result)
    Subscription.any_instance.stubs(:active?).returns(true)
    Subscription.any_instance.stubs(:total_amount).returns(0)
    @account.subscription.update_attributes(agent_limit: '6')
    @account.subscription.update_attributes(subscription_plan_id: SubscriptionPlan.current.map(&:id).third)
    @controller.stubs(:load_coupon).returns(nil)
    @controller.stubs(:set_current_account).returns(@account)
    @controller.stubs(:request_host).returns('test6.freshpo.com')

    post :plan, construct_params({}, params.merge!(params_hash.except(:agent_limit)))
    @account.reload
    assert_equal @account.subscription.additional_info[:field_agent_limit], nil
    assert_response 302
  ensure
    ChargeBee::Subscription.unstub(:update)
    ChargeBee::Subscription.unstub(:retrieve)
    Subscription.any_instance.unstub(:active?)
    @account.destroy
  end

  def test_same_plan_disable_fsm
    create_sample_account('test7', 'test7@freshdesk.com')
    Account.stubs(:current).returns(@account)
    params = { agent_limit: '1', addons: { field_service_management: { enabled: 'false' } } }
    @account.launch(:downgrade_policy)
    @account.rollback(:addon_based_billing)
    result = ChargeBee::Result.new(stub_update_params(@account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    ChargeBee::Subscription.stubs(:retrieve).returns(result)
    Subscription.any_instance.stubs(:active?).returns(true)
    Subscription.any_instance.stubs(:total_amount).returns(0)
    @account.subscription.update_attributes(agent_limit: '6')
    @account.subscription.update_attributes(subscription_plan_id: SubscriptionPlan.current.map(&:id).third)
    @controller.stubs(:load_coupon).returns(nil)
    @controller.stubs(:set_current_account).returns(@account)
    @controller.stubs(:request_host).returns('test7.freshpo.com')

    post :plan, construct_params({}, params.merge!(params_hash.except(:agent_limit))) 
    @account.reload
    assert_equal @account.subscription.subscription_request.fsm_field_agents, nil
    assert_response 302
  ensure
    ChargeBee::Subscription.unstub(:update)
    ChargeBee::Subscription.unstub(:retrieve)
    Subscription.any_instance.unstub(:active?)
    @account.destroy
  end

  def test_same_plan_fsm_agent_seats_decrease
    create_sample_account('test8', 'test8@freshdesk.com')
    Account.stubs(:current).returns(@account)
    params = { agent_limit: '1', addons: { field_service_management: { enabled: 'true', value: '1' } } }
    @account.launch(:downgrade_policy)
    @account.launch(:addon_based_billing)
    result = ChargeBee::Result.new(stub_update_params(@account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    ChargeBee::Subscription.stubs(:retrieve).returns(result)
    Subscription.any_instance.stubs(:active?).returns(true)
    Subscription.any_instance.stubs(:total_amount).returns(0)
    @account.subscription.update_attributes(agent_limit: '6')
    @account.subscription.update_attributes(additional_info: { field_agent_limit: 3 })
    @account.subscription.update_attributes(subscription_plan_id: SubscriptionPlan.current.map(&:id).third)
    @controller.stubs(:load_coupon).returns(nil)
    @controller.stubs(:set_current_account).returns(@account)
    @controller.stubs(:request_host).returns('test8.freshpo.com')

    post :plan, construct_params({}, params.merge!(params_hash.except(:agent_limit)))
    @account.reload
    assert_equal @account.subscription.additional_info[:field_agent_limit], 3
    assert_equal @account.subscription.subscription_request.fsm_field_agents, 1
    assert_response 302
  ensure
    ChargeBee::Subscription.unstub(:update)
    ChargeBee::Subscription.unstub(:retrieve)
    Subscription.any_instance.unstub(:active?)
    @account.destroy
  end

  def test_subscription_without_LP
    create_sample_account('test10', 'test10@freshdesk.com')
    Account.stubs(:current).returns(@account)
    current_plan_id = SubscriptionPlan.current.map(&:id).third
    @account.rollback(:downgrade_policy)
    @account.launch(:addon_based_billing)
    result = ChargeBee::Result.new(stub_update_params(@account.id))
    ChargeBee::Subscription.stubs(:update).returns(result)
    ChargeBee::Subscription.stubs(:retrieve).returns(result)
    Subscription.any_instance.stubs(:active?).returns(true)
    Subscription.any_instance.stubs(:total_amount).returns(0)
    @account.subscription.update_attributes(subscription_plan_id: current_plan_id)
    @controller.stubs(:load_coupon).returns(nil)
    @controller.stubs(:set_current_account).returns(@account)
    @controller.stubs(:request_host).returns('test10.freshpo.com')
    
    post :plan, construct_params({ plan_id: current_plan_id - 1 }.merge!(params_hash.except(:plan_id)))
    @account.reload
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_response 302
  ensure
    ChargeBee::Subscription.unstub(:update)
    ChargeBee::Subscription.unstub(:retrieve)
    Subscription.any_instance.unstub(:active?)
    @account.destroy
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

  private

    def params_hash
      plan_id = SubscriptionPlan.current.map(&:id).third
      {
        currency: 'USD',
        plan_id: plan_id,
        billing_cycle: SubscriptionPlan.current.third.renewal_period,
        agent_limit: '1'
      }
    end

    def stub_update_params(account_id)
      {
        'subscription':
          {
            'id': account_id, 'plan_id': 'blossom_jan_19_annual',
            'plan_quantity': 1, 'status': 'active', 'trial_start': 1556863974,
            'trial_end': 1556864678, 'current_term_start': 1557818479,
            'current_term_end': 1589440879, 'created_at': 1368442623,
            'started_at': 1368442623, 'activated_at': 1556891503,
            'has_scheduled_changes': false, 'object': 'subscription',
            'coupon': '1FREEAGENT', 'coupons': [{ 'coupon_id': '1FREEAGENT',
            'applied_count': 38, 'object': 'coupon' }], 'due_invoices_count': 0
          },
          'customer': { 'id': '1', 'first_name': 'Ethan hunt',
                        'last_name': 'Ethan hunt', 'email': 'meaghan.bergnaum@kaulke.com',
                        'company': 'freshdesk', 'auto_collection': 'on',
                        'allow_direct_debit': false, 'created_at': 1368442623,
                        'taxability': 'taxable', 'object': 'customer',
                        'billing_address': { 'first_name': 'asdasd', 'last_name': 'asdasasd',
                                             'line1': 'A14, Sree Prasad Apt, Jeswant Nagar, Mugappair West',
                                             'city': 'Chennai', 'state_code': 'TN', 'state': 'Tamil Nadu',
                                             'country': 'IN', 'zip': '600037', 'object': 'billing_address' },
                        'card_status': 'valid',
                        'payment_method': { 'object': 'payment_method', 'type': 'card',
                                            'reference_i': 'tok_HngTopzRQR3BKK1E17', 'gateway': 'chargebee',
                                            'status': 'valid' },
                        'account_credits': 0, 'refundable_credits': 4553100, 'excess_payments': 0,
                        'cf_account_domain': 'aut.freshpo.com', 'meta_data': { 'customer_key': 'fdesk.1' } },
          'card': { 'status': 'valid', 'gateway': 'chargebee', 'first_name': 'sdasd',
                    'last_name': 'asdasd', 'iin': '411111', 'last4': '1111', 'card_type': 'visa',
                    'expiry_month': 12, 'expiry_year': 2020, 'billing_addr1': 'A14, Sree Prasad Apt',
                    'billing_addr2': 'Jeswant Nagar, Mugappair West', 'billing_city': 'Chennai',
                    'billing_state_code': 'TN', 'billing_state': 'Tamil Nadu', 'billing_country': 'IN',
                    'billing_zip': '600037', 'ip_address': '182.73.13.166', 'object': 'card',
                    'masked_number': '************1111', 'customer_id': '1' }
      }
    end
end
