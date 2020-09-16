require_relative '../test_helper'
require 'minitest/spec'
class ProxyFeatureTest < ActiveSupport::TestCase
  DB_PLAN_FEATURES = Account::PLANS_AND_FEATURES.collect { |key, value| value[:features] }.flatten!.uniq!
  ALL_DB_FEATURES = Account::SELECTABLE_FEATURES.keys + Account::TEMPORARY_FEATURES.keys +
    Account::ADMIN_CUSTOMER_PORTAL_FEATURES.keys + DB_PLAN_FEATURES
  TEARDOWN_CREATE_FEATURES = Account::ADMIN_CUSTOMER_PORTAL_FEATURES.
    merge(Account::SELECTABLE_FEATURES).merge(Account::TEMPORARY_FEATURES).
    select{ |k, v| v }.keys + DB_PLAN_FEATURES
  TEARDOWN_REMOVE_FEATURES = ALL_DB_FEATURES - TEARDOWN_CREATE_FEATURES

  def setup
    create_test_account
    @account = Account.current || Account.first.make_current
    destroy_all_db_features
  end

  def teardown
    create_all_db_features(TEARDOWN_CREATE_FEATURES)
    destroy_all_db_features(TEARDOWN_REMOVE_FEATURES)
  end

  def create_all_db_features(features = nil)
    (features || ALL_DB_FEATURES).each { |feature| @account.features.safe_send(feature).create }
  end

  def destroy_all_db_features(features = nil)
    (features || ALL_DB_FEATURES).each { |feature| @account.features.safe_send(feature).destroy }
  end

  def check_feature(feature)
    feature_name = Account::FEATURE_NAME_CHANGES[feature] || feature
    if Account::DB_TO_LP_FEATURES.include?(feature)
      @account.launched?(feature_name)
    else
      @account.has_feature?(feature_name)
    end
  end

  def test_create_method_with_current_account_set
    create_all_db_features
    ALL_DB_FEATURES.each { |feature| assert(check_feature(feature), "Expected true, but its false: #{feature}") }
  end

  def test_feature_check_method
    db_features = create_all_db_features
    db_features.each do |feature|
      assert(@account.features.safe_send("#{feature}?"), "Expected true, but its false: #{feature}")
    end
  end

  def test_save_method
    ALL_DB_FEATURES.each { |feature| refute(check_feature(feature), "Expected false, but its true: #{feature}") }
    ALL_DB_FEATURES.each { |feature| @account.features.safe_send(feature).save }
    ALL_DB_FEATURES.each { |feature| assert(check_feature(feature), "Expected true, but its false: #{feature}") }
  end

  def test_build_method
    ALL_DB_FEATURES.each { |feature| refute(check_feature(feature), "Expected false, but its true: #{feature}") }
    @account.features.build(*ALL_DB_FEATURES)
    @account.save!
    ALL_DB_FEATURES.each { |feature| assert(check_feature(feature), "Expected true, but its false: #{feature}") }
  end

  def test_delete_method
    create_all_db_features
    ALL_DB_FEATURES.each { |feature| @account.features.safe_send(feature).delete }
    ALL_DB_FEATURES.each { |feature| refute(check_feature(feature), "Expected false, but its true: #{feature}") }
  end

  def test_account_update_features_method
    params = { features: { open_forums: false, open_solutions: false, hide_portal_forums: true } }
    [:open_forums, :open_solutions].each { |feature| @account.add_feature(feature) }
    @account.revoke_feature(:hide_portal_forums)
    assert @account.has_feature?(:open_forums), 'open_forums should be true'
    assert @account.has_feature?(:open_solutions), 'open_solutions should be true'
    refute @account.has_feature?(:hide_portal_forums), 'hide_portal_forums should be false'

    @account.update_attributes!(params)

    refute @account.has_feature?(:open_forums), 'open_forums should be false'
    refute @account.has_feature?(:open_solutions), 'open_solutions should be false'
    assert @account.has_feature?(:hide_portal_forums), 'hide_portal_forums should be true'
  end

  def test_launch_party_feature_flags
    Account::DB_TO_LP_FEATURES.each { |feature| @account.launch(feature) }
    Account::DB_TO_LP_FEATURES.each { |feature| assert(@account.features?(feature), "Expected true, but its false: #{feature}") }
    Account::DB_TO_LP_FEATURES.each { |feature| @account.rollback(feature) }
    Account::DB_TO_LP_FEATURES.each { |feature| refute(@account.features?(feature), "Expected false, but its true: #{feature}") }
    @account.add_feature :open_solutions
    assert(@account.features?(:open_solutions), "Expected true, but its false: open_solutions")
    @account.revoke_feature :open_solutions
    refute(@account.features?(:open_solutions), "Expected false, but its true: open_solutions")
  end
end
