require_relative '../../api/test_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'automations_test_helper.rb')
require Rails.root.join('test', 'models', 'helpers', 'subscription_test_helper.rb')
class SubscriptionsControllerTest < ActionController::TestCase
  include AccountTestHelper
  include SubscriptionTestHelper
  include Redis::OthersRedis
  include Redis::Keys::Others
  include TicketFieldsTestHelper
  include ::Admin::AdvancedTicketing::FieldServiceManagement::Util
  include AutomationsHelper

  def setup
    Subscription.any_instance.stubs(:freshdesk_freshsales_bundle_enabled?).returns(false)
    Account.any_instance.stubs(:omni_accounts_present_in_org?).returns(false)
    super
  end

  def teardown
    Subscription.any_instance.unstub(:freshdesk_freshsales_bundle_enabled?)
    Account.any_instance.unstub(:omni_accounts_present_in_org?)
  end

  def wrap_cname(params)
    params
  end

  def test_subscription_downgrade_to_sprout
    plan_ids = SubscriptionPlan.current.map(&:id)
    sprout_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount == 0.0 }.compact.first
    params = { plan_id: sprout_plan_id }
    stub_chargebee_requests
    @account.rollback(:downgrade_policy)
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    assert_equal @account.subscription.subscription_request.nil?, true
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, sprout_plan_id
    assert_response 302

    params_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount != 0.0 }.compact.first
    params = { plan_id: params_plan_id }
    current_subscription = @account.subscription
    current_subscription.agent_limit = 1
    current_subscription.save!
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    @account.reload
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_equal @account.subscription.subscription_plan_id, params_plan_id
    assert_response 302
  ensure
    unstub_chargebee_requests
  end

  def test_subscription_check_slareminder_key_after_signup
    create_new_account('test1', 'test1@freshdesk.com')
    update_currency
    Account.stubs(:current).returns(@account)
    assert_equal @account.has_feature?(:sla_reminder_automation), true
  ensure
    @account.destroy
  end

=begin
  def test_bitmap_twitter_automation_feature_present_for_estate_and_above
    plan_ids = SubscriptionPlan.current.map(&:id)
    sprout_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount == 0.0 }.compact.first
    params = { plan_id: sprout_plan_id }
    stub_chargebee_requests
    assert_equal @account.has_feature?(:twitter_field_automation), true
    @account.rollback(:downgrade_policy)
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    assert_equal @account.subscription.subscription_request.nil?, true
    @account.reload
    assert_equal @account.has_feature?(:twitter_field_automation), false
  ensure
    unstub_chargebee_requests
  end
=end

  def test_handle_agents_when_moving_from_non_paying_plan_without_dp_enabled
    plan_ids = SubscriptionPlan.current.map(&:id)
    stub_chargebee_requests
    current_plan_id = @account.subscription.subscription_plan_id
    params_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount != 0.0 }.compact.first
    params = { plan_id: params_plan_id, agent_limit: @account.full_time_support_agents.count - 1 }
    SubscriptionPlan.any_instance.stubs(:amount).returns(0)
    @account.rollback(:downgrade_policy)
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id, :agent_limit)))
    @account.reload
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_equal @account.subscription.subscription_plan_id, current_plan_id
    assert_response 302
  ensure
    unstub_chargebee_requests
    SubscriptionPlan.any_instance.unstub(:amount)
  end

  def test_handle_agents_when_moving_from_non_paying_plan_with_dp_enabled
    plan_ids = SubscriptionPlan.current.map(&:id)
    stub_chargebee_requests
    current_plan_id = @account.subscription.subscription_plan_id
    params_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount != 0.0 }.compact.first
    params = { plan_id: params_plan_id, agent_limit: @account.full_time_support_agents.count - 1 }
    SubscriptionPlan.any_instance.stubs(:amount).returns(0)
    @account.subscription.agent_limit = 1
    @account.subscription.save!
    @account.launch(:downgrade_policy)
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id, :agent_limit)))
    @account.reload
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_equal @account.subscription.subscription_plan_id, current_plan_id
    assert_response 302
  ensure
    unstub_chargebee_requests
    Account.any_instance.unstub(:launched?)
    SubscriptionPlan.any_instance.unstub(:amount)
  end

  def test_handle_agents_when_moving_from_paying_plan_with_dp_enabled
    plan_ids = SubscriptionPlan.current.map(&:id)
    stub_chargebee_requests
    current_plan_id = @account.subscription.subscription_plan_id
    params_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount != 0.0 }.compact.first
    params = { plan_id: params_plan_id, agent_limit: @account.full_time_support_agents.count - 1 }
    SubscriptionPlan.any_instance.stubs(:amount).returns(35.00)
    current_subscription = @account.subscription
    current_subscription.agent_limit = 1
    current_subscription.free_agents = 3
    current_subscription.save!
    @account.launch(:downgrade_policy)
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id, :agent_limit)))
    @account.reload
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_equal @account.subscription.subscription_plan_id, current_plan_id
    assert_response 302
  ensure
    unstub_chargebee_requests
    SubscriptionPlan.any_instance.unstub(:amount)
    Account.any_instance.unstub(:launched?)
  end

  def test_handle_agents_when_moving_from_paying_plan_without_dp_enabled
    plan_ids = SubscriptionPlan.current.map(&:id)
    stub_chargebee_requests
    current_plan_id = @account.subscription.subscription_plan_id
    params_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount != 0.0 }.compact.first
    params = { plan_id: params_plan_id, agent_limit: @account.full_time_support_agents.count - 1 }
    SubscriptionPlan.any_instance.stubs(:amount).returns(35.00)
    current_subscription = @account.subscription
    current_subscription.state = 'active'
    current_subscription.save!
    @account.rollback :downgrade_policy
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id, :agent_limit)))
    @account.reload
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_equal @account.subscription.subscription_plan_id, current_plan_id
    assert_response 302
  ensure
    unstub_chargebee_requests
    SubscriptionPlan.any_instance.unstub(:amount)
  end

  def test_handle_agents_when_moving_from_paying_plan_without_dp_enabled_in_trial
    plan_ids = SubscriptionPlan.current.map(&:id)
    stub_chargebee_requests
    current_plan_id = @account.subscription.subscription_plan_id
    params_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount != 0.0 }.compact.first
    params = { plan_id: params_plan_id, agent_limit: @account.full_time_support_agents.count - 1 }
    SubscriptionPlan.any_instance.stubs(:amount).returns(35.00)
    current_subscription = @account.subscription
    current_subscription.state = 'trial'
    current_subscription.save!
    @account.rollback :downgrade_policy
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id, :agent_limit)))
    @account.reload
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_equal @account.subscription.subscription_plan_id, current_plan_id
    assert_response 302
  ensure
    unstub_chargebee_requests
    SubscriptionPlan.any_instance.unstub(:amount)
  end

  def test_handle_agents_when_moving_from_non_paying_plan_without_dp_enabled_in_trial
    plan_ids = SubscriptionPlan.current.map(&:id)
    stub_chargebee_requests
    current_plan_id = @account.subscription.subscription_plan_id
    params_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount != 0.0 }.compact.first
    params = { plan_id: params_plan_id, agent_limit: @account.full_time_support_agents.count - 1 }
    SubscriptionPlan.any_instance.stubs(:amount).returns(0)
    current_subscription = @account.subscription
    current_subscription.state = 'trial'
    current_subscription.save!
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id, :agent_limit)))
    @account.reload
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_equal @account.subscription.subscription_plan_id, current_plan_id
    assert_response 302
  ensure
    unstub_chargebee_requests
    SubscriptionPlan.any_instance.unstub(:amount)
  end

  def test_handle_agents_when_moving_from_paying_plan_with_dp_enabled_in_trial
    plan_ids = SubscriptionPlan.current.map(&:id)
    stub_chargebee_requests
    current_plan_id = @account.subscription.subscription_plan_id
    params_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount != 0.0 }.compact.first
    params = { plan_id: params_plan_id, agent_limit: @account.full_time_support_agents.count - 1 }
    SubscriptionPlan.any_instance.stubs(:amount).returns(35.00)
    current_subscription = @account.subscription
    current_subscription.state = 'trial'
    current_subscription.save!
    @account.launch(:downgrade_policy)
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id, :agent_limit)))
    @account.reload
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_equal @account.subscription.subscription_plan_id, current_plan_id
    assert_response 302
  ensure
    unstub_chargebee_requests
    SubscriptionPlan.any_instance.unstub(:amount)
    Account.any_instance.unstub(:launched?)
  end

  def test_handle_agents_when_moving_from_non_paying_plan_with_dp_enabled_in_trial
    plan_ids = SubscriptionPlan.current.map(&:id)
    stub_chargebee_requests
    current_plan_id = @account.subscription.subscription_plan_id
    params_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount != 0.0 }.compact.first
    params = { plan_id: params_plan_id, agent_limit: @account.full_time_support_agents.count - 1 }
    SubscriptionPlan.any_instance.stubs(:amount).returns(0)
    current_subscription = @account.subscription
    current_subscription.state = 'trial'
    current_subscription.save!
    @account.launch(:downgrade_policy)
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id, :agent_limit)))
    @account.reload
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_equal @account.subscription.subscription_plan_id, current_plan_id
    assert_response 302
  ensure
    unstub_chargebee_requests
    SubscriptionPlan.any_instance.unstub(:amount)
    Account.any_instance.unstub(:launched?)
  end

  def test_handle_field_agents_when_moving_from_trial_with_dp_enabled
    params = { agent_limit: '1', addons: { field_service_management: { enabled: 'true', value: '1' } } }
    stub_chargebee_requests
    Account.any_instance.stubs(:field_agents_count).returns(2)
    current_subscription = @account.subscription
    current_subscription.state = 'trial'
    current_subscription.agent_limit = 6
    current_subscription.additional_info[:field_agent_limit] = 3
    current_subscription.save!
    post :plan, construct_params({}, params.merge!(params_hash.except(:agent_limit)))
    @account.reload
    assert_equal @account.subscription.additional_info[:field_agent_limit], 3
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_response 302
  ensure
    unstub_chargebee_requests
    Account.any_instance.unstub(:field_agents_count)
  end

  def test_handle_field_agents_when_moving_from_trial_without_dp_enabled
    params = { agent_limit: '1', addons: { field_service_management: { enabled: 'true', value: '1' } } }
    stub_chargebee_requests
    Account.any_instance.stubs(:field_agents_count).returns(2)
    @account.rollback(:downgrade_policy)
    current_subscription = @account.subscription
    current_subscription.state = 'trial'
    current_subscription.agent_limit = 6
    current_subscription.additional_info[:field_agent_limit] = 3
    current_subscription.save!
    post :plan, construct_params({}, params.merge!(params_hash.except(:agent_limit)))
    @account.reload
    assert_equal @account.subscription.additional_info[:field_agent_limit], 3
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_response 302
  ensure
    unstub_chargebee_requests
    Account.any_instance.unstub(:field_agents_count)
  end

  def test_handle_field_agents_when_moving_from_active_with_dp_enabled
    params = { agent_limit: '1', addons: { field_service_management: { enabled: 'true', value: '1' } } }
    stub_chargebee_requests
    Account.any_instance.stubs(:field_agents_count).returns(2)
    current_subscription = @account.subscription
    current_subscription.agent_limit = 6
    current_subscription.additional_info[:field_agent_limit] = 3
    current_subscription.save!
    post :plan, construct_params({}, params.merge!(params_hash.except(:agent_limit)))
    @account.reload
    assert_equal @account.subscription.additional_info[:field_agent_limit], 3
    assert_equal @account.subscription.subscription_request.fsm_field_agents, 1
    assert_response 302
  ensure
    unstub_chargebee_requests
    Account.any_instance.unstub(:field_agents_count)
  end

  def test_subscription_change_with_fsm_enabled_to_fsm_disabled
    params = { agent_limit: '10', addons: { field_service_management: { enabled: 'false' } } }
    stub_chargebee_requests
    current_subscription = @account.subscription
    current_subscription.agent_limit = 6
    current_subscription.additional_info[:field_agent_limit] = 0
    current_subscription.save!
    @account.launch(:downgrade_policy)
    post :plan, construct_params({}, params.merge!(params_hash.except(:agent_limit)))
    @account.reload
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_response 302
  ensure
    unstub_chargebee_requests
    @account.rollback(:downgrade_policy)
  end

  def test_handle_field_agents_when_moving_from_active_without_dp_enabled
    params = { agent_limit: '1', addons: { field_service_management: { enabled: 'true', value: '1' } } }
    stub_chargebee_requests
    Account.any_instance.stubs(:field_agents_count).returns(2)
    @account.rollback(:downgrade_policy)
    current_subscription = @account.subscription
    current_subscription.agent_limit = 6
    current_subscription.additional_info[:field_agent_limit] = 3
    current_subscription.save!
    post :plan, construct_params({}, params.merge!(params_hash.except(:agent_limit)))
    @account.reload
    assert_equal @account.subscription.additional_info[:field_agent_limit], 3
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_response 302
  ensure
    unstub_chargebee_requests
    Account.any_instance.unstub(:field_agents_count)
  end

  def test_handle_subscription_with_agent_field_agent_and_product_reduction
    plan_ids = SubscriptionPlan.current.map(&:id)
    stub_chargebee_requests
    stub_fsm_field_agents
    get_multi_product_plans
    current_plan_id = @account.subscription.subscription_plan_id
    current_agents = @account.subscription.agent_limit
    params_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount != 0.0 }.compact.first
    params = { plan_id: params_plan_id, agent_limit: @account.full_time_support_agents.count - 1, addons: { field_service_management: { enabled: 'true', value: '1' } } }
    6.times { @account.products.new(name: Faker::Lorem.characters(5)) }
    @account.save!
    @account.subscription.additional_info[:field_agent_limit] = 3
    @account.subscription.save!
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id, :agent_limit)))
    @account.reload
    assert_equal @account.subscription.agent_limit, current_agents
    assert_equal @account.subscription.additional_info[:field_agent_limit], 3
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_equal @account.subscription.subscription_plan_id, current_plan_id
    assert_response 302
  ensure
    unstub_chargebee_requests
    unstub_fsm_field_agents
    SubscriptionPlan.any_instance.unstub(:unlimited_multi_product?)
    SubscriptionPlan.any_instance.unstub(:multi_product?)
    Account.any_instance.unstub(:launched?)
  end

  def test_handle_subscription_with_agent_and_field_agent
    plan_ids = SubscriptionPlan.current.map(&:id)
    stub_chargebee_requests
    stub_fsm_field_agents
    current_plan_id = @account.subscription.subscription_plan_id
    params_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount != 0.0 }.compact.first
    to_plan =  SubscriptionPlan.find(params_plan_id)
    params = { plan_id: params_plan_id, agent_limit: @account.full_time_support_agents.count - 1, addons: { field_service_management: { enabled: 'true', value: '1' } } }
    Account.any_instance.stubs(:launched?).returns(false)
    @account.revoke_feature(:unlimited_multi_product)
    @account.subscription.additional_info[:field_agent_limit] = 3
    @account.subscription.save!
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id, :agent_limit)))
    @account.reload
    assert_equal @account.subscription.additional_info[:field_agent_limit], 3
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_equal @account.subscription.subscription_plan_id, current_plan_id
    assert_response 302
  ensure
    unstub_chargebee_requests
    unstub_fsm_field_agents
    Account.any_instance.unstub(:launched?)
  end

  def test_handle_subscription_with_agent_and_product_reduction
    plan_ids = SubscriptionPlan.current.map(&:id)
    stub_chargebee_requests
    get_multi_product_plans
    current_plan_id = @account.subscription.subscription_plan_id
    params_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount != 0.0 }.compact.first
    params = { plan_id: params_plan_id, agent_limit: @account.full_time_support_agents.count - 1 }
    6.times { @account.products.new(name: Faker::Lorem.characters(5)) }
    @account.save!
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id, :agent_limit)))
    @account.reload
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_equal @account.subscription.subscription_plan_id, current_plan_id
    assert_response 302
  ensure
    unstub_chargebee_requests
    SubscriptionPlan.any_instance.unstub(:unlimited_multi_product?)
    SubscriptionPlan.any_instance.unstub(:multi_product?)
    Account.any_instance.unstub(:launched?)
  end

  def test_handle_subscription_with_field_agents_and_product_reduction
    plan_ids = SubscriptionPlan.current.map(&:id)
    stub_chargebee_requests
    stub_fsm_field_agents
    get_multi_product_plans
    current_plan_id = @account.subscription.subscription_plan_id
    params_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount != 0.0 }.compact.first
    params = { plan_id: params_plan_id, addons: { field_service_management: { enabled: 'true', value: '1' } } }
    6.times { @account.products.new(name: Faker::Lorem.characters(5)) }
    @account.save!
    @account.subscription.additional_info[:field_agent_limit] = 3
    @account.subscription.save!
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id, :agent_limit)))
    @account.reload
    assert_equal @account.subscription.additional_info[:field_agent_limit], 3
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_equal @account.subscription.subscription_plan_id, current_plan_id
    assert_response 302
  ensure
    unstub_chargebee_requests
    unstub_fsm_field_agents
    SubscriptionPlan.any_instance.unstub(:unlimited_multi_product?)
    SubscriptionPlan.any_instance.unstub(:multi_product?)
    Account.any_instance.unstub(:launched?)
  end

  def test_new_subscription_plan_change
    current_plan_id = @account.subscription.subscription_plan_id
    params_plan_id = SubscriptionPlan.current.map(&:id).second
    stub_chargebee_requests
    @account.subscription.agent_limit = 1
    @account.subscription.save!
    post :plan, construct_params({}, { agent_limit: '12', plan_id: params_plan_id }.merge!(params_hash.except(:plan_id, :agent_limit)))
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, params_plan_id
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_response 302
  ensure
    unstub_chargebee_requests
  end

  def test_subscription_plan_change_with_limited_multi_product_feature
    current_plan_id = @account.subscription.subscription_plan_id
    params_plan_id = SubscriptionPlan.current.map(&:id).second
    PLANS[:subscription_plans][SubscriptionPlan.current.second.canon_name][:features] << :multi_product
    stub_chargebee_requests
    @account.rollback :downgrade_policy
    @account.add_feature(:unlimited_multi_product)
    5.times { @account.products.new(name: Faker::Lorem.characters(5)) }
    @account.save!
    post :plan, construct_params({}, { plan_id: params_plan_id }.merge!(params_hash.except(:plan_id)))
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, params_plan_id
    assert_equal @account.products.count, AccountConstants::MULTI_PRODUCT_LIMIT
    assert_response 302
  end

  def test_same_plan_billing_cycle
    current_plan_id = @account.subscription.subscription_plan_id
    stub_chargebee_requests
    params = { agent_limit: '12', plan_id: current_plan_id, billing_cycle: SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual] }
    current_subscription = @account.subscription
    current_subscription.agent_limit = 1
    current_subscription.renewal_period = 1
    current_subscription.save!
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
    current_subscription = @account.subscription
    current_subscription.agent_limit = 1
    current_subscription.renewal_period = SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual]
    current_subscription.save!
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
    current_subscription = @account.subscription
    current_subscription.agent_limit = 1
    current_subscription.renewal_period = SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual]
    current_subscription.save!
    current_subscription.account.rollback :downgrade_policy
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id, :billing_cycle)))
    current_subscription.reload
    assert_equal current_subscription.account.launched?(:downgrade_policy), true
    assert_equal @account.subscription.subscription_request.nil?, true
    assert_response 302
  ensure
    unstub_chargebee_requests
  end

  def test_same_plan_agent_limit
    params = { plan_id: @account.subscription.subscription_plan_id, agent_limit: '6' }
    stub_chargebee_requests
    @account.subscription.agent_limit = 1
    @account.subscription.save!
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
    @account.subscription.agent_limit = 6
    @account.subscription.save!
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
    @account.subscription.agent_limit = 6
    @account.subscription.save!
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
    @account.subscription.agent_limit = 6
    @account.subscription.save!
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
    @account.subscription.agent_limit = 6
    @account.subscription.save!
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

  def test_fsm_artifacts_with_9_date_fields
    params = { agent_limit: '1', addons: { field_service_management: { enabled: 'true', value: ' ' } } }
    stub_chargebee_requests
    @account.subscription.update_attributes(agent_limit: '6')
    (@account.custom_date_fields_from_cache.count..8).each do |i|
      create_custom_field('date_time' + i.to_s, 'date')
    end
    post :plan, construct_params({}, params.merge!(params_hash.except(:agent_limit)))
    @account.reload
    assert_response 302
    assert_equal @account.subscription.additional_info[:field_agent_limit], nil
    assert_equal I18n.t('fsm_requirements_not_met'), flash[:notice]
  ensure
    unstub_chargebee_requests
  end

  def test_fsm_text_fields_with_normalized_flexi_field_with_limit_reached
    params = { agent_limit: '1', addons: { field_service_management: { enabled: 'true', value: ' ' } } }
    Account.any_instance.stubs(:denormalized_flexifields_enabled?).returns(false)
    stub_chargebee_requests
    (1..2).each do |i|
      create_custom_field('text' + i.to_s, 'text')
    end
    stub_const(Helpdesk::Ticketfields::Constants, 'MAX_ALLOWED_COUNT', string: 4, text: 10, number: 20, date: 10, boolean: 10, decimal: 10) do
      stub_const(Helpdesk::Ticketfields::Constants, 'TICKET_FIELD_DATA_COUNT', string: 4, text: 10, number: 20, date: 10, boolean: 10, decimal: 10) do
        post :plan, construct_params({}, params.merge!(params_hash.except(:agent_limit)))
        @account.reload
        assert_response 302
        assert_equal @account.subscription.additional_info[:field_agent_limit], nil
        assert_equal I18n.t('fsm_requirements_not_met'), flash[:notice]
      end
    end
  ensure
    unstub_chargebee_requests
    Account.any_instance.unstub(:denormalized_flexifields_enabled?)
  end

  def test_fsm_text_fields_with_denormalized_flexi_field_with_limit_reached
    params = { agent_limit: '1', addons: { field_service_management: { enabled: 'true', value: ' ' } } }
    Account.any_instance.stubs(:denormalized_flexifields_enabled?).returns(true)
    stub_chargebee_requests
    (1..2).each do |i|
      create_custom_field('text' + i.to_s, 'text')
    end
    stub_const(Helpdesk::Ticketfields::Constants, 'MAX_ALLOWED_COUNT_DN', string: 4, text: 10, number: 20, date: 10, boolean: 10, decimal: 10) do
      post :plan, construct_params({}, params.merge!(params_hash.except(:agent_limit)))
      @account.reload
      assert_response 302
      assert_equal @account.subscription.additional_info[:field_agent_limit], nil
      assert_equal I18n.t('fsm_requirements_not_met'), flash[:notice]
    end
  ensure
    unstub_chargebee_requests
    Account.any_instance.unstub(:denormalized_flexifields_enabled?)
  end

  def test_enable_fsm_and_upgrade_with_fsm
    stub_chargebee_requests
    forest_plan_id = SubscriptionPlan.select(:id).where(name: 'Forest Jan 19').map(&:id).last
    @account.reload
    params = { addons: { field_service_management: { enabled: 'true', value: '0' } } }
    @account.rollback :downgrade_policy
    post :plan, construct_params({}, params.merge!(params_hash))
    @account.reload
    assert_equal true, @account.field_service_management_enabled?
    assert_equal true, @account.parent_child_infra_enabled?

    params[:plan_id] = forest_plan_id
    @account.rollback :downgrade_policy
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    @account.reload
    assert_equal true, @account.field_service_management_enabled?
    assert_equal true, @account.parent_child_infra_enabled?
    assert_equal @account.subscription.subscription_plan_id, forest_plan_id
  ensure
    cleanup_fsm
    unstub_chargebee_requests
  end

  def test_fsm_toggle_enabled_for_garden_plan
    stub_chargebee_requests
    garden_plan_id = SubscriptionPlan.select(:id).where(name: 'Garden Omni Jan 19').map(&:id).last
    @account.reload
    params = { plan_id: garden_plan_id }
    @account.rollback :downgrade_policy
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, garden_plan_id
    assert_equal true, @account.field_service_management_toggle_enabled?
    refute @account.parent_child_infra_enabled?
  ensure
    cleanup_fsm
    unstub_chargebee_requests
  end

  def test_fsm_enabled_when_downgrade_to_garden_with_fsm_enabled
    stub_chargebee_requests
    SAAS::SubscriptionEventActions.any_instance.stubs(:handle_collab_feature).returns(true)
    Subscription.any_instance.stubs(:add_to_crm).returns(true)
    garden_plan_id = SubscriptionPlan.select(:id).where(name: 'Garden Omni Jan 19').map(&:id).last
    @account.reload
    @account.add_feature(:field_service_management) unless @account.field_service_management_enabled?
    perform_fsm_operations
    params = { plan_id: garden_plan_id }
    @account.rollback :downgrade_policy
    Sidekiq::Testing.inline! do
      post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    end
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, garden_plan_id
    assert_equal true, @account.field_service_management_enabled?
  ensure
    cleanup_fsm
    SAAS::SubscriptionEventActions.any_instance.unstub(:handle_collab_feature)
    Subscription.any_instance.unstub(:add_to_crm)
    unstub_chargebee_requests
  end

  def test_fsm_dependent_features_present_when_downgrade_to_garden_with_fsm_enabled
    stub_chargebee_requests
    garden_plan_id = SubscriptionPlan.select(:id).where(name: 'Garden Omni Jan 19').map(&:id).last
    @account.reload
    @account.add_feature(:field_service_management) unless @account.field_service_management_enabled?
    perform_fsm_operations
    params = { plan_id: garden_plan_id }
    @account.rollback :downgrade_policy
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, garden_plan_id
    assert_equal true, @account.has_feature?(:dynamic_sections)
    assert_equal true, @account.parent_child_infra_enabled?
    assert_equal true, @account.roles.find_by_name(Helpdesk::Roles::FIELD_TECHNICIAN_ROLE[:name]).present?
  ensure
    cleanup_fsm
    unstub_chargebee_requests
  end

  def test_fsm_disabled_when_downgrade_to_garden_with_fsm_disabled
    stub_chargebee_requests
    SAAS::SubscriptionEventActions.any_instance.stubs(:handle_collab_feature).returns(true)
    Subscription.any_instance.stubs(:add_to_crm).returns(true)
    garden_plan_id = SubscriptionPlan.select(:id).where(name: 'Garden Omni Jan 19').map(&:id).last
    @account.reload
    params = { plan_id: garden_plan_id }
    @account.rollback :downgrade_policy
    Sidekiq::Testing.inline! do
      post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    end
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, garden_plan_id
    refute @account.field_service_management_enabled?
    refute @account.has_feature?(:parent_child_infra)
  ensure
    SAAS::SubscriptionEventActions.any_instance.unstub(:handle_collab_feature)
    Subscription.any_instance.unstub(:add_to_crm)
    unstub_chargebee_requests
  end

=begin
  def test_fsm_dependent_features_removed_when_downgrade_from_estate_to_garden_with_fsm_disabled
    stub_chargebee_requests
    garden_plan_id = SubscriptionPlan.select(:id).where(name: 'Garden Omni Jan 19').map(&:id).last
    @account.reload
    params = { plan_id: garden_plan_id }
    @account.rollback :downgrade_policy
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, garden_plan_id
    refute @account.has_feature?(:dynamic_sections)
    refute @account.parent_child_infra_enabled?
  ensure
    unstub_chargebee_requests
  end
=end

  def test_enable_fsm_when_downgrade_from_estate_to_garden_through_ui_fsm_toggle
    stub_chargebee_requests
    garden_plan_id = SubscriptionPlan.select(:id).where(name: 'Garden Omni Jan 19').map(&:id).last
    @account.reload
    params = { plan_id: garden_plan_id, addons: { field_service_management: { enabled: 'true', value: '0' } } }
    @account.rollback :downgrade_policy
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, garden_plan_id
    assert_equal true, @account.field_service_management_enabled?
    assert_equal true, @account.has_feature?(:dynamic_sections)
    assert_equal true, @account.parent_child_infra_enabled?
  ensure
    cleanup_fsm
    unstub_chargebee_requests
  end

  def test_disable_fsm_when_downgrade_from_estate_to_garden_through_ui_fsm_toggle
    stub_chargebee_requests
    @account.reload
    @account.add_feature(:field_service_management) unless @account.field_service_management_enabled?
    perform_fsm_operations
    garden_plan_id = SubscriptionPlan.select(:id).where(name: 'Garden Omni Jan 19').map(&:id).last
    params = { plan_id: garden_plan_id, addons: { field_service_management: { enabled: 'false', value: '0' } } }
    @account.rollback :downgrade_policy
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, garden_plan_id
    refute @account.field_service_management_enabled?
    refute @account.has_feature?(:dynamic_sections)
    refute @account.parent_child_infra_enabled?
  ensure
    cleanup_fsm
    unstub_chargebee_requests
  end

  def test_dynamic_sections_data_cleanup_when_downgrade_from_estate_to_garden_with_fsm_disabled
    stub_chargebee_requests
    SAAS::SubscriptionEventActions.any_instance.stubs(:handle_collab_feature).returns(true)
    Subscription.any_instance.stubs(:add_to_crm).returns(true)
    garden_plan_id = SubscriptionPlan.select(:id).where(name: 'Garden Omni Jan 19').map(&:id).last
    @account.reload
    params = { plan_id: garden_plan_id, addons: { field_service_management: { enabled: 'false', value: '0' } } }
    @account.rollback :downgrade_policy
    Sidekiq::Testing.inline! do
      post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    end
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, garden_plan_id
    assert_equal 0, @account.sections.count
    assert_equal 0, @account.section_fields.count
    assert_equal 0, ticket_fields.all.select { |field| field.field_options['section'] == true }.count
  ensure
    SAAS::SubscriptionEventActions.any_instance.unstub(:handle_collab_feature)
    Subscription.any_instance.unstub(:add_to_crm)
    unstub_chargebee_requests
  end

  def test_dynamic_sections_data_cleanup_when_downgrade_from_estate_to_fsm_garden_plans_with_fsm_enabled
    stub_chargebee_requests
    SAAS::SubscriptionEventActions.any_instance.stubs(:handle_collab_feature).returns(true)
    Subscription.any_instance.stubs(:add_to_crm).returns(true)
    garden_plan_id = SubscriptionPlan.select(:id).where(name: 'Garden Omni Jan 19').map(&:id).last
    @account.reload
    @account.add_feature(:field_service_management) unless @account.field_service_management_enabled?
    perform_fsm_operations
    params = { plan_id: garden_plan_id }
    fsm_fields_count =  @account.sections.where(label: SERVICE_TASK_SECTION).first.section_fields.count
    @account.rollback :downgrade_policy
    Sidekiq::Testing.inline! do
      post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    end
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, garden_plan_id
    assert_equal true, @account.sections.find_by_label(SERVICE_TASK_SECTION).present?
    assert_equal fsm_fields_count, @account.sections.where(label: SERVICE_TASK_SECTION).first.section_fields.count
    refute @account.section_fields.empty?
    assert_equal 0, ticket_fields.all.select { |field| field.field_options['section'] == true && !field.field_options.include?('fsm') }.count
    assert_equal true, ticket_fields.all.select { |field| field.field_options['section'] == true && field.field_options.include?('fsm') }.present?
  ensure
    cleanup_fsm
    SAAS::SubscriptionEventActions.any_instance.unstub(:handle_collab_feature)
    Subscription.any_instance.unstub(:add_to_crm)
    unstub_chargebee_requests
  end

  def test_fsm_toggle_enabled_for_blossom_plan
    stub_chargebee_requests
    blossom_plan_id = SubscriptionPlan.select(:id).where(name: 'Blossom Jan 19').map(&:id).last
    @account.reload
    params = { plan_id: blossom_plan_id }
    @account.rollback :downgrade_policy
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, blossom_plan_id
    assert_equal true, @account.field_service_management_toggle_enabled?
  ensure
    cleanup_fsm
    unstub_chargebee_requests
  end

  def test_fsm_enabled_when_downgrade_from_estate_to_blossom_with_fsm_enabled
    stub_chargebee_requests
    SAAS::SubscriptionEventActions.any_instance.stubs(:handle_collab_feature).returns(true)
    Subscription.any_instance.stubs(:add_to_crm).returns(true)
    blossom_plan_id = SubscriptionPlan.select(:id).where(name: 'Blossom Jan 19').map(&:id).last
    @account.reload
    @account.add_feature(:field_service_management) unless @account.field_service_management_enabled?
    perform_fsm_operations
    params = { plan_id: blossom_plan_id }
    @account.rollback :downgrade_policy
    Sidekiq::Testing.inline! do
      post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    end
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, blossom_plan_id
    assert_equal true, @account.field_service_management_enabled?
  ensure
    cleanup_fsm
    SAAS::SubscriptionEventActions.any_instance.unstub(:handle_collab_feature)
    Subscription.any_instance.unstub(:add_to_crm)
    unstub_chargebee_requests
  end

  def test_fsm_dependent_feature_present_when_downgrade_from_estate_to_blossom_with_fsm_enabled
    stub_chargebee_requests
    blossom_plan_id = SubscriptionPlan.select(:id).where(name: 'Blossom Jan 19').map(&:id).last
    @account.reload
    @account.add_feature(:field_service_management) unless @account.field_service_management_enabled?
    perform_fsm_operations
    params = { plan_id: blossom_plan_id }
    @account.rollback :downgrade_policy
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, blossom_plan_id
    assert_equal true, @account.has_feature?(:dynamic_sections)
    assert_equal true, @account.parent_child_infra_enabled?
    assert_equal true, @account.roles.find_by_name(Helpdesk::Roles::FIELD_TECHNICIAN_ROLE[:name]).present?
  ensure
    cleanup_fsm
    unstub_chargebee_requests
  end

  def test_fsm_disabled_when_downgrade_from_estate_to_blossom_with_fsm_disabled
    stub_chargebee_requests
    SAAS::SubscriptionEventActions.any_instance.stubs(:handle_collab_feature).returns(true)
    Subscription.any_instance.stubs(:add_to_crm).returns(true)
    blossom_plan_id = SubscriptionPlan.select(:id).where(name: 'Blossom Jan 19').map(&:id).last
    @account.reload
    params = { plan_id: blossom_plan_id }
    @account.rollback :downgrade_policy
    Sidekiq::Testing.inline! do
      post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    end
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, blossom_plan_id
    refute @account.field_service_management_enabled?
    refute @account.has_feature?(:parent_child_infra)
  ensure
    SAAS::SubscriptionEventActions.any_instance.unstub(:handle_collab_feature)
    Subscription.any_instance.unstub(:add_to_crm)
    unstub_chargebee_requests
  end

=begin
  def test_fsm_dependent_features_removed_when_downgrade_from_estate_to_blossom_with_fsm_disabled
    stub_chargebee_requests
    blossom_plan_id = SubscriptionPlan.select(:id).where(name: 'Blossom Jan 19').map(&:id).last
    @account.reload
    params = { plan_id: blossom_plan_id }
    @account.rollback :downgrade_policy
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, blossom_plan_id
    refute @account.has_feature?(:dynamic_sections)
    refute @account.has_feature?(:parent_child_infra)
  ensure
    unstub_chargebee_requests
  end
=end

  def test_enable_fsm_when_downgrade_from_estate_to_blossom_through_ui_fsm_toggle
    stub_chargebee_requests
    blossom_plan_id = SubscriptionPlan.select(:id).where(name: 'Blossom Jan 19').map(&:id).last
    @account.reload
    params = { plan_id: blossom_plan_id, addons: { field_service_management: { enabled: 'true', value: '0' } } }
    @account.rollback :downgrade_policy
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, blossom_plan_id
    assert_equal true, @account.field_service_management_enabled?
    assert_equal true, @account.has_feature?(:dynamic_sections)
    assert_equal true, @account.parent_child_infra_enabled?
  ensure
    cleanup_fsm
    unstub_chargebee_requests
  end

  def test_disable_fsm_when_downgrade_from_estate_to_blossom_through_ui_fsm_toggle
    stub_chargebee_requests
    @account.reload
    @account.add_feature(:field_service_management) unless @account.field_service_management_enabled?
    perform_fsm_operations
    blossom_plan_id = SubscriptionPlan.select(:id).where(name: 'Blossom Jan 19').map(&:id).last
    params = { plan_id: blossom_plan_id, addons: { field_service_management: { enabled: 'false', value: '0' } } }
    @account.rollback :downgrade_policy
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, blossom_plan_id
    refute @account.field_service_management_enabled?
    refute @account.has_feature?(:dynamic_sections)
    refute @account.parent_child_infra_enabled?
  ensure
    cleanup_fsm
    unstub_chargebee_requests
  end

  def test_dynamic_sections_data_cleanup_when_downgrade_from_estate_to_blossom_with_fsm_disabled
    stub_chargebee_requests
    SAAS::SubscriptionEventActions.any_instance.stubs(:handle_collab_feature).returns(true)
    Subscription.any_instance.stubs(:add_to_crm).returns(true)
    blossom_plan_id = SubscriptionPlan.select(:id).where(name: 'Blossom Jan 19').map(&:id).last
    @account.reload
    params = { plan_id: blossom_plan_id, addons: { field_service_management: { enabled: 'false', value: '0' } } }
    @account.rollback :downgrade_policy
    Sidekiq::Testing.inline! do
      post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    end
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, blossom_plan_id
    assert_equal 0, @account.sections.count
    assert_equal 0, @account.section_fields.count
    assert_equal 0, ticket_fields.all.select { |field| field.field_options['section'] == true }.count
  ensure
    SAAS::SubscriptionEventActions.any_instance.unstub(:handle_collab_feature)
    Subscription.any_instance.unstub(:add_to_crm)
    unstub_chargebee_requests
  end

  def test_dynamic_sections_data_cleanup_when_downgrade_from_estate_to_blossom_with_fsm_enabled
    stub_chargebee_requests
    SAAS::SubscriptionEventActions.any_instance.stubs(:handle_collab_feature).returns(true)
    Subscription.any_instance.stubs(:add_to_crm).returns(true)
    blossom_plan_id = SubscriptionPlan.select(:id).where(name: 'Blossom Jan 19').map(&:id).last
    @account.reload
    @account.add_feature(:field_service_management) unless @account.field_service_management_enabled?
    perform_fsm_operations
    params = { plan_id: blossom_plan_id }
    fsm_fields_count = @account.sections.where(label: SERVICE_TASK_SECTION).first.section_fields.count
    @account.rollback :downgrade_policy
    Sidekiq::Testing.inline! do
      post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    end
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, blossom_plan_id
    assert_equal true, @account.sections.find_by_label(SERVICE_TASK_SECTION).present?
    assert_equal fsm_fields_count, @account.sections.where(label: SERVICE_TASK_SECTION).first.section_fields.count
    refute @account.section_fields.empty?
    assert_equal 0, ticket_fields.all.select { |field| field.field_options['section'] == true && !field.field_options.include?('fsm') }.count
    assert_equal true, ticket_fields.all.select { |field| field.field_options['section'] == true && field.field_options.include?('fsm') }.present?
  ensure
    cleanup_fsm
    SAAS::SubscriptionEventActions.any_instance.unstub(:handle_collab_feature)
    Subscription.any_instance.unstub(:add_to_crm)
    unstub_chargebee_requests
  end

=begin
  def test_disable_fsm_when_downgrade_from_estate_to_sprout_with_fsm_enabled
    stub_chargebee_requests
    Account.any_instance.stubs(:automation_revamp_enabled?).returns(true)
    SAAS::SubscriptionEventActions.any_instance.stubs(:handle_collab_feature).returns(true)
    SAAS::SubscriptionEventActions.any_instance.stubs(:handle_feature_add_data).returns(true)
    Subscription.any_instance.stubs(:add_to_crm).returns(true)
    service_task_dispatcher = create_dispatchr_rule(rule_type: VAConfig::SERVICE_TASK_DISPATCHER_RULE)
    assert service_task_dispatcher.present?
    service_task_observer = create_observer_rule(rule_type: VAConfig::SERVICE_TASK_OBSERVER_RULE)
    assert service_task_observer.present?
    plan_ids = SubscriptionPlan.current.map(&:id)
    sprout_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount == 0.0 }.compact.first
    @account.reload
    @account.add_feature(:field_service_management) unless @account.field_service_management_enabled?
    perform_fsm_operations
    params = { plan_id: sprout_plan_id }
    @account.rollback :downgrade_policy
    Sidekiq::Testing.inline! do
      post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    end
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, sprout_plan_id
    assert_equal true, @account.all_service_task_dispatcher_rules.empty?
    assert_equal true, @account.all_service_task_observer_rules.empty?
    refute @account.field_service_management_enabled?
    refute @account.parent_child_infra_enabled?
  ensure
    cleanup_fsm
    SAAS::SubscriptionEventActions.any_instance.unstub(:handle_collab_feature)
    SAAS::SubscriptionEventActions.any_instance.unstub(:handle_feature_add_data)
    Subscription.any_instance.unstub(:add_to_crm)
    unstub_chargebee_requests
    Account.any_instance.unstub(:automation_revamp_enabled?)
  end
=end

=begin
  def test_fsm_dependent_features_removed_when_downgrade_from_estate_to_sprout_with_fsm_enabled
    stub_chargebee_requests
    plan_ids = SubscriptionPlan.current.map(&:id)
    sprout_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount == 0.0 }.compact.first
    @account.reload
    @account.add_feature(:field_service_management) unless @account.field_service_management_enabled?
    perform_fsm_operations
    params = { plan_id: sprout_plan_id }
    @account.rollback :downgrade_policy
    post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, sprout_plan_id
    refute @account.has_feature?(:dynamic_sections)
  ensure
    cleanup_fsm
    unstub_chargebee_requests
  end
=end

=begin
  def test_sections_data_cleanup_when_downgrade_from_estate_to_sprout_with_fsm_enabled
    stub_chargebee_requests
    SAAS::SubscriptionEventActions.any_instance.stubs(:handle_collab_feature).returns(true)
    SAAS::SubscriptionEventActions.any_instance.stubs(:handle_feature_add_data).returns(true)
    Subscription.any_instance.stubs(:add_to_crm).returns(true)
    plan_ids = SubscriptionPlan.current.map(&:id)
    sprout_plan_id = SubscriptionPlan.current.where(id: plan_ids).map { |x| x.id if x.amount == 0.0 }.compact.first
    @account.reload
    @account.add_feature(:field_service_management) unless @account.field_service_management_enabled?
    perform_fsm_operations
    params = { plan_id: sprout_plan_id }
    @account.rollback :downgrade_policy
    Sidekiq::Testing.inline! do
      post :plan, construct_params({}, params.merge!(params_hash.except(:plan_id)))
    end
    @account.reload
    assert_equal @account.subscription.subscription_plan_id, sprout_plan_id
    assert_equal 0, @account.sections.count
    assert_equal 0, @account.section_fields.count
    assert_equal 0, ticket_fields.all.select { |field| field.field_options['section'] == true }.count
  ensure
    cleanup_fsm
    SAAS::SubscriptionEventActions.any_instance.unstub(:handle_collab_feature)
    Subscription.any_instance.unstub(:add_to_crm)
    SAAS::SubscriptionEventActions.any_instance.unstub(:handle_feature_add_data)
    unstub_chargebee_requests
  end
=end

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
      @controller.stubs(:set_current_account).returns(@account)
      @controller.stubs(:request_host).returns('test1.freshpo.com')
      @account.subscription.state = 'active'
      @account.subscription.save!
    end

    def stub_fsm_field_agents
      Account.any_instance.stubs(:field_service_management_enabled_changed?).returns(false)
      Account.any_instance.stubs(:field_agents_count).returns(2)
    end

    def unstub_fsm_field_agents
      Account.any_instance.unstub(:field_service_management_enabled_changed?)
      Account.any_instance.unstub(:launched?)
      Subscription.any_instance.unstub(:active?)
      Subscription.any_instance.unstub(:trial?)
      Account.any_instance.unstub(:field_agents_count)
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

    def get_multi_product_plans
      SubscriptionPlan.any_instance.stubs(:unlimited_multi_product?).returns(false)
      SubscriptionPlan.any_instance.stubs(:multi_product?).returns(true)
      Account.any_instance.stubs(:launched?).returns(false)
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
