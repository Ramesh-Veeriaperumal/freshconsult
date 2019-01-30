require_relative '../unit_test_helper'

class PricingPlanChange2019Test < ActionView::TestCase
  def setup
    @account = Account.first
    @account.make_current
  end

  def test_to_features_list_without_launchparty_feature
    @account.rollback(:pricing_plan_change_2019)
    features = (Account::PRICING_PLAN_MIGRATION_FEATURES_2019.to_a - @account.features_list)
    assert features.blank?
  end

  def test_to_features_list_with_launchparty_feature
    added = [:social_tab, :customize_table_view]
    removed = [:add_to_response, :agent_scope]
    added.each { |feature| @account.add_feature(feature) }
    removed.each { |feature| @account.revoke_feature(feature) }
    @account.launch(:pricing_plan_change_2019)
    features_list = Account.current.reload.features_list
    assert ((added & features_list).count == 2), "Should contain :social_tab, \
      :customize_table_view features"
    assert ((removed - features_list).count == 2), "Shouldn't contain :agent_scope, \
      :add_to_response features"
  end

  def test_has_feature_without_launchparty_feature
    @account.rollback(:pricing_plan_change_2019)
    Account::PRICING_PLAN_MIGRATION_FEATURES_2019.each do |feature|
      assert Account.current.has_feature?(feature)
    end
    @account.revoke_feature(:add_watcher)
    refute @account.reload.has_feature?(:add_watcher)
    @account.add_feature(:add_watcher)
    assert @account.reload.has_feature?(:add_watcher)
  end

  def test_has_feature_with_feature_launched
    added = [:social_tab, :customize_table_view]
    removed = [:add_to_response, :agent_scope]
    added.each { |feature| @account.add_feature(feature) }
    removed.each { |feature| @account.revoke_feature(feature) }
    @account.launch(:pricing_plan_change_2019)
    added.each { |feature| assert @account.has_feature?(feature) }
    removed.each { |feature| refute @account.has_feature?(feature) }
    @account.revoke_feature(:add_watcher)
    refute @account.reload.has_feature?(:add_watcher)
    @account.add_feature(:add_watcher)
    assert @account.reload.has_feature?(:add_watcher)
  end

  def test_has_features_without_launchparty_feature
    @account.rollback(:pricing_plan_change_2019)
    @account.revoke_feature(:add_watcher)
    @account.revoke_feature(:advanced_facebook)
    refute @account.reload.has_features?(:add_watcher, :advanced_facebook)
    @account.add_feature(:add_watcher)
    refute @account.reload.has_features?(:add_watcher, :advanced_facebook)
    @account.add_feature(:advanced_facebook)
    @account.revoke_feature(:social_tab)
    assert @account.reload.has_features?(:add_watcher, :advanced_facebook, :social_tab)
  end

  def test_has_features_with_launchparty_feature
    @account.launch(:pricing_plan_change_2019)
    @account.revoke_feature(:add_watcher)
    @account.revoke_feature(:advanced_facebook)
    refute @account.reload.has_features?(:add_watcher, :advanced_facebook)
    @account.add_feature(:add_watcher)
    refute @account.reload.has_features?(:add_watcher, :advanced_facebook)
    @account.add_feature(:advanced_facebook)
    @account.revoke_feature(:social_tab)
    refute @account.reload.has_features?(:add_watcher, :advanced_facebook, :social_tab)
    @account.add_feature(:social_tab)
    assert @account.reload.has_features?(:add_watcher, :advanced_facebook, :social_tab)
  end
end
