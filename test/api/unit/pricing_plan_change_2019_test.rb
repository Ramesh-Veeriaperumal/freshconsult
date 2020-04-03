require_relative '../unit_test_helper'

class PricingPlanChange2019Test < ActionView::TestCase
  def setup
    @account = Account.first
    @account.make_current
  end

  def test_to_features_list
    added = [:customer_journey]
    added.each { |feature| @account.add_feature(feature) }
    features_list = Account.current.reload.features_list
    assert ((added & features_list).count == 1), 'Should contain :customer_journey'
  end

  def test_has_feature
    added = [:customer_journey]
    added.each { |feature| @account.add_feature(feature) }
    added.each { |feature| assert @account.has_feature?(feature) }
    @account.revoke_feature(:add_watcher)
    refute @account.reload.has_feature?(:add_watcher)
    @account.add_feature(:add_watcher)
    assert @account.reload.has_feature?(:add_watcher)
  end

  def test_has_features_without_launchparty_feature
    @account.rollback(:pricing_plan_change_2020)
    @account.revoke_feature(:add_watcher)
    @account.revoke_feature(:advanced_facebook)
    refute @account.reload.has_features?(:add_watcher, :advanced_facebook)
    @account.add_feature(:add_watcher)
    refute @account.reload.has_features?(:add_watcher, :advanced_facebook)
    @account.add_feature(:advanced_facebook)
    @account.revoke_feature(:unlimited_multi_product)
    assert @account.reload.has_features?(:add_watcher, :advanced_facebook, :unlimited_multi_product)
  end

  def test_has_features
    @account.revoke_feature(:add_watcher)
    @account.revoke_feature(:advanced_facebook)
    refute @account.reload.has_features?(:add_watcher, :advanced_facebook)
    @account.add_feature(:add_watcher)
    refute @account.reload.has_features?(:add_watcher, :advanced_facebook)
    @account.add_feature(:advanced_facebook)
    @account.revoke_feature(:customer_journey)
    refute @account.reload.has_features?(:add_watcher, :advanced_facebook, :customer_journey)
    @account.add_feature(:customer_journey)
    assert @account.reload.has_features?(:add_watcher, :advanced_facebook, :customer_journey)
  end
end
