require_relative '../test_helper'
['account_test_helper.rb'].each { |file| require Rails.root.join("test/core/helpers/#{file}") }

class SubscriptionEventActionsTest < ActionView::TestCase
  include AccountTestHelper

  def setup
    super
    Account.stubs(:current).returns(@account)
  end

  def teardown
    @account.revoke_feature(:omni_channel_routing)
    @account.revoke_feature(:lbrr_by_omniroute)
    @account.add_feature(:round_robin_load_balancing)
    @account.unstub(:subscription)
    Account.unstub(:current)
  end

  def test_plan_upgrade_from_garden_to_estate
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
  end

  def test_plan_upgrade_from_garden_to_estate_with_feature_settings_when_lp_is_enabled
    Account.current.launch(:feature_based_settings)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Garden Jan 19').id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    save_account_subscription(SubscriptionPlan.find_by_name('Estate Jan 20').id)
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert_equal @account.solutions_agent_metrics_enabled?, false
    assert_equal @account.location_tagging_enabled?, false
  ensure
    Account.current.rollback(:feature_based_settings)
  end

  def test_plan_upgrade_from_garden_to_estate_with_feature_settings_lp_is_disabled
    @account.disable_setting(:solutions_agent_metrics)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Garden Jan 19').id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    save_account_subscription(SubscriptionPlan.find_by_name('Estate Jan 20').id)
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert_equal @account.solutions_agent_metrics_enabled?, false
    assert_equal @account.location_tagging_enabled?, false
  end

  def test_estate_feature_settings_when_plan_downgrade_from_forest_to_estate
    Account.current.add_feature(:solutions_agent_metrics_feature)
    Account.current.enable_setting(:solutions_agent_metrics)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Forest Jan 19').id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    save_account_subscription(SubscriptionPlan.find_by_name('Estate Jan 20').id)
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert @account.solutions_agent_metrics_feature_enabled?
    assert @account.solutions_agent_metrics_enabled?
  end

  def test_estate_feature_settings_when_plan_downgrade_from_estate_to_garden
    Account.current.add_feature(:solutions_agent_metrics_feature)
    Account.current.enable_setting(:solutions_agent_metrics)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Estate Jan 19').id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    new_subscription = save_account_subscription(SubscriptionPlan.find_by_name('Garden Jan 20').id)
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    assert_equal @account.solutions_agent_metrics_feature_enabled?, false
    assert_equal @account.solutions_agent_metrics_enabled?, false
  ensure
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Garden Jan 20').id, state: 'active', account_id: @account.id))
    save_account_subscription(old_subscription.subscription_plan_id)
    SAAS::SubscriptionEventActions.new(@account, new_subscription).change_plan
  end

  def test_reset_of_enabled_fsm_settings_when_downgrade_to_sprout
    # setup
    Account.current.launch(:feature_based_settings)
    @account.add_feature(:field_service_management_toggle) unless @account.field_service_management_toggle_enabled?
    @account.add_feature(:field_service_management) unless @account.field_service_management_enabled?
    fsm_settings = AccountSettings::SettingToSettingsMapping[:field_service_management] | AccountSettings::FeatureToSettingsMapping[:field_service_management_toggle]
    fsm_settings.each { |setting| @account.enable_setting(setting) }
    fsm_settings.each { |setting| assert @account.safe_send("#{setting}_enabled?") }
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Estate Jan 19').id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    new_subscription = save_account_subscription(SubscriptionPlan.select(:id).where(name: 'Sprout Jan 19').first.id)
    # when
    features_to_skip = SubscriptionConstants::FSM_ADDON_PARAMS_NAMES_MAP.values.uniq.map(&:to_sym)
    SAAS::SubscriptionEventActions.new(@account, old_subscription, [], features_to_skip).change_plan
    # then
    fsm_settings.each { |setting| assert_equal false, @account.has_feature?(setting) }
  ensure
    Account.current.rollback(:feature_based_settings)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Sprout Jan 19').id, state: 'active', account_id: @account.id))
    save_account_subscription(old_subscription.subscription_plan_id)
    SAAS::SubscriptionEventActions.new(@account, new_subscription).change_plan
  end

  # field_service_management will be passed in skipped feature, so reset settings should be skipped while disabling FSM and is handled in handle_feature_drop_data
  def test_skip_reset_of_enabled_fsm_settings_when_downgrade_estate_to_any_fsm_supported_plan_with_fsm_disabled
    # setup
    Account.current.launch(:feature_based_settings)
    fsm_settings = AccountSettings::SettingToSettingsMapping[:field_service_management] | AccountSettings::FeatureToSettingsMapping[:field_service_management_toggle]
    fsm_settings.each { |setting| @account.add_feature(setting) }
    @account.revoke_feature(:field_service_management)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Estate Jan 19').id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    new_subscription = save_account_subscription(SubscriptionPlan.select(:id).where(name: 'Blossom Jan 19').first.id)
    # when
    features_to_skip = SubscriptionConstants::FSM_ADDON_PARAMS_NAMES_MAP.values.uniq.map(&:to_sym)
    SAAS::SubscriptionEventActions.new(@account, old_subscription, [], features_to_skip).change_plan
    # then
    fsm_settings.each { |setting| assert_equal true, @account.has_feature?(setting) }
  ensure
    Account.current.rollback(:feature_based_settings)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Blossom Jan 19').id, state: 'active', account_id: @account.id))
    save_account_subscription(old_subscription.subscription_plan_id)
    SAAS::SubscriptionEventActions.new(@account, new_subscription).change_plan
  end

  def test_retain_settings_state_when_upgrade_to_higher_plan
    Account.current.launch(:feature_based_settings)
    Account.any_instance.stubs(:auto_response_detector_enabled?).returns(true)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Estate Jan 19').id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    new_subscription = save_account_subscription(SubscriptionPlan.select(:id).where(name: 'Forest Jan 19').first.id)
    @account.disable_setting(:signup_link)
    @account.disable_setting(:open_solutions)
    @account.enable_setting(:disable_supress_logs)
    @account.enable_setting(:personalized_email_replies)
    @account.enable_setting(:auto_response_detector_toggle)
    # when
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    # then
    assert_equal false, @account.signup_link_enabled?
    assert_equal false, @account.open_solutions_enabled?
    assert_equal true, @account.disable_supress_logs_enabled?
    assert_equal true, @account.personalized_email_replies_enabled?
    assert_equal true, @account.auto_response_detector_toggle_enabled?
  ensure
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Forest Jan 19').id, state: 'active', account_id: @account.id))
    save_account_subscription(old_subscription.subscription_plan_id)
    SAAS::SubscriptionEventActions.new(@account, new_subscription).change_plan
    Account.unstub(:auto_response_detector_enabled?)
    Account.current.rollback(:feature_based_settings)
  end

  def test_retain_settings_state_when_downgrade_if_dependent_feature_is_supported_in_lower_plan
    # setup
    Account.current.launch(:feature_based_settings)
    Account.any_instance.stubs(:auto_response_detector_enabled?).returns(true)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Estate Jan 19').id, state: 'active', account_id: @account.id))
    old_subscription = @account.subscription.dup
    new_subscription = save_account_subscription(SubscriptionPlan.select(:id).where(name: 'Blossom Jan 19').first.id)
    @account.disable_setting(:signup_link)
    @account.disable_setting(:open_solutions)
    @account.enable_setting(:disable_supress_logs)
    @account.enable_setting(:personalized_email_replies)
    @account.enable_setting(:auto_response_detector_toggle)

    # when
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    # then
    assert_equal false, @account.signup_link_enabled?
    assert_equal false, @account.open_solutions_enabled?
    assert_equal true, @account.disable_supress_logs_enabled?
    assert_equal true, @account.personalized_email_replies_enabled?
    assert_equal true, @account.auto_response_detector_toggle_enabled?
  ensure
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Blossom Jan 19').id, state: 'active', account_id: @account.id))
    save_account_subscription(old_subscription.subscription_plan_id)
    SAAS::SubscriptionEventActions.new(@account, new_subscription).change_plan
    Account.unstub(:auto_response_detector_enabled?)
    Account.current.rollback(:feature_based_settings)
  end

  def test_do_not_retain_settings_state_when_downgrade_if_dependent_feature_is_not_supported_in_lower_plan
    # setup
    Account.current.launch(:feature_based_settings)
    Account.any_instance.stubs(:auto_response_detector_enabled?).returns(true)
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Estate Jan 19').id, state: 'active', account_id: @account.id))
    @account.add_feature(:solutions_agent_metrics_feature) unless @account.solutions_agent_metrics_feature_enabled?
    old_subscription = @account.subscription.dup
    new_subscription = save_account_subscription(SubscriptionPlan.select(:id).where(name: 'Sprout Jan 19').first.id)
    @account.enable_setting(:solutions_agent_metrics)
    @account.enable_setting(:auto_response_detector_toggle)
    # when
    SAAS::SubscriptionEventActions.new(@account, old_subscription).change_plan
    # then
    assert_equal false, @account.has_feature?(:solutions_agent_metrics)
    assert_equal false, @account.solutions_agent_metrics_enabled?

    assert_equal false, @account.auto_response_detector_toggle_enabled?

  ensure
    @account.stubs(:subscription).returns(Subscription.new(subscription_plan_id: SubscriptionPlan.find_by_name('Blossom Jan 19').id, state: 'active', account_id: @account.id))
    save_account_subscription(old_subscription.subscription_plan_id)
    SAAS::SubscriptionEventActions.new(@account, new_subscription).change_plan
    Account.unstub(:auto_response_detector_enabled?)
    Account.current.rollback(:feature_based_settings)
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
  end

  def test_plan_upgrade_from_new_estate_to_forest
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
  end

  def test_plan_downgrade_from_old_forest_to_estate
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
  end

  def test_plan_downgrade_from_new_forest_to_estate
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
    @account.unstub(:fluffy_email_enabled?)
  end

  private

    def save_account_subscription(new_plan_id)
      new_subscription = @account.subscription
      new_subscription.subscription_plan_id = new_plan_id
      new_subscription.save
      new_subscription
    end
end
