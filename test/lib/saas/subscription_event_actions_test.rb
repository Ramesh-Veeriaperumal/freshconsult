require_relative '../test_helper'
['account_test_helper.rb'].each { |file| require Rails.root.join("test/core/helpers/#{file}") }

class SubscriptionEventActionsTest < ActionView::TestCase
  include AccountTestHelper

  def teardown
    @account.revoke_feature(:omni_channel_routing)
    @account.revoke_feature(:lbrr_by_omniroute)
    @account.add_feature(:round_robin_load_balancing)
  end

  def test_plan_upgrade_from_garden_to_estate
    Account.stubs(:current).returns(@account)
    @account.revoke_feature(:omni_channel_routing)
    @account.revoke_feature(:lbrr_by_omniroute)
    @account.revoke_feature(:round_robin_load_balancing)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Garden Jan 19').id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    s = @account.subscription
    s.subscription_plan_id = SubscriptionPlan.find_by_name('Estate Jan 19').id
    s.save
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert @account.omni_channel_routing_enabled?
    assert @account.lbrr_by_omniroute_enabled?
  ensure
    Account.unstub(:current)
    @account.unstub(:subscription)
  end

  def test_plan_upgrade_from_garden_to_estate_with_feature_settings_when_lp_is_enabled
    Account.stubs(:current).returns(@account)
    Account.current.launch(:feature_based_settings)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Garden Jan 19').id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    s = @account.subscription
    s.subscription_plan_id = SubscriptionPlan.find_by_name('Estate Jan 19').id
    s.save
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert @account.has_feature?(:untitled_setting_3)
  ensure
    Account.current.rollback(:feature_based_settings)
    Account.unstub(:current)
    @account.unstub(:subscription)
  end

  def test_plan_upgrade_from_garden_to_estate_with_feature_settings_lp_is_disabled
    Account.stubs(:current).returns(@account)
    @account.revoke_feature(:untitled_setting_3)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Garden Jan 19').id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    s = @account.subscription
    s.subscription_plan_id = SubscriptionPlan.find_by_name('Estate Jan 19').id
    s.save
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert_equal @account.has_feature?(:untitled_setting_3), false
  ensure
    Account.unstub(:current)
    @account.unstub(:subscription)
  end

  def test_estate_feature_settings_when_plan_downgrade_from_forest_to_estate
    Account.stubs(:current).returns(@account)
    Account.current.add_feature(:untitled_feature_2_dependency_toggle)
    Account.current.add_feature(:untitled_setting_3)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Forest Jan 19').id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    s = @account.subscription
    s.subscription_plan_id = SubscriptionPlan.find_by_name('Estate Jan 19').id
    s.save
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert @account.has_feature?(:untitled_feature_2_dependency_toggle)
    assert @account.has_feature?(:untitled_setting_3)
  ensure
    Account.unstub(:current)
    @account.unstub(:subscription)
  end

  def test_estate_feature_settings_when_plan_downgrade_from_estate_to_garden
    Account.stubs(:current).returns(@account)
    Account.current.add_feature(:untitled_feature_2_dependency_toggle)
    Account.current.add_feature(:untitled_setting_3)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Estate Jan 19').id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    s = @account.subscription
    s.subscription_plan_id = SubscriptionPlan.find_by_name('Garden Jan 19').id
    s.save
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert_equal @account.has_feature?(:untitled_feature_2_dependency_toggle), false
    assert_equal @account.has_feature?(:untitled_setting_3), false
  ensure
    Account.unstub(:current)
    @account.unstub(:subscription)
  end

  def test_plan_upgrade_from_old_estate_to_forest
    Account.stubs(:current).returns(@account)
    @account.add_feature(:omni_channel_routing)
    @account.revoke_feature(:lbrr_by_omniroute)
    @account.add_feature(:round_robin_load_balancing)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Estate Jan 19').id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    s = @account.subscription
    s.subscription_plan_id = SubscriptionPlan.find_by_name('Forest Jan 19').id
    s.save
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert @account.omni_channel_routing_enabled?
    assert !@account.lbrr_by_omniroute_enabled?
  ensure
    Account.unstub(:current)
    @account.unstub(:subscription)
  end

  def test_plan_upgrade_from_new_estate_to_forest
    Account.stubs(:current).returns(@account)
    @account.add_feature(:omni_channel_routing)
    @account.add_feature(:lbrr_by_omniroute)
    @account.add_feature(:round_robin_load_balancing)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Estate Jan 19').id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    s = @account.subscription
    s.subscription_plan_id = SubscriptionPlan.find_by_name('Forest Jan 19').id
    s.save
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert @account.omni_channel_routing_enabled?
    assert @account.lbrr_by_omniroute_enabled?
  ensure
    Account.unstub(:current)
  end

  def test_plan_downgrade_from_old_forest_to_estate
    Account.stubs(:current).returns(@account)
    @account.add_feature(:omni_channel_routing)
    @account.revoke_feature(:lbrr_by_omniroute)
    @account.add_feature(:round_robin_load_balancing)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Estate Jan 19').id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    s = @account.subscription
    s.subscription_plan_id = SubscriptionPlan.find_by_name('Forest Jan 19').id
    s.save
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert @account.omni_channel_routing_enabled?
    assert !@account.lbrr_by_omniroute_enabled?
  ensure
    Account.unstub(:current)
  end

  def test_plan_downgrade_from_new_forest_to_estate
    Account.stubs(:current).returns(@account)
    @account.add_feature(:omni_channel_routing)
    @account.add_feature(:lbrr_by_omniroute)
    @account.add_feature(:round_robin_load_balancing)
    @account.stubs(:fluffy_email_enabled?).returns(true)
    @account.expects(:change_fluffy_email_limit).once
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Estate Jan 19').id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    s = @account.subscription
    s.subscription_plan_id = SubscriptionPlan.find_by_name('Forest Jan 19').id
    s.save
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert @account.omni_channel_routing_enabled?
    assert @account.lbrr_by_omniroute_enabled?
  ensure
    Account.unstub(:current)
    @account.unstub(:fluffy_email_enabled?)
  end
end
