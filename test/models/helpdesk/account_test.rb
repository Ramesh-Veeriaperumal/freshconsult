require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'test_case_methods.rb')

class AccountTest < ActiveSupport::TestCase
  include AccountTestHelper

  def setup
    create_test_account if @account.nil?
  end

  def test_account_find_with_valid_account_id
    Rails.logger.debug "Account helper inspection #{@account.inspect}"
    assert_equal Account.find(@account.id), @account
  end

  def test_account_not_found_custom_error_for_invalid_account_id
    invalid_id = Account.maximum(:id) + 100
    assert_raises Account::RecordNotFound do
      Account.find(invalid_id)
    end
  end

  def test_enable_secure_attachments
    @account.revoke_feature(:private_inline)
    @account.add_feature(:secure_attachments)
    assert @account.private_inline_enabled?
  ensure
    @account.revoke_feature(:secure_attachments)
  end

  def test_disable_secure_attachments
    @account.add_feature(:secure_attachments)
    @account.add_feature(:private_inline)
    @account.revoke_feature(:secure_attachments)
    assert_equal @account.private_inline_enabled?, false
  ensure
    @account.revoke_feature(:private_inline)
  end

  def test_enable_setting_with_launch_party
    launch_party = Account::LP_FEATURES.last
    is_lp_enabled = @account.send("#{launch_party}_enabled?")
    @account.rollback(launch_party)
    assert_equal @account.send("#{launch_party}_enabled?"), false
    @account.enable_setting(launch_party)
    assert @account.send("#{launch_party}_enabled?")
  ensure
    is_lp_enabled ? @account.launch(launch_party) : @account.rollback(launch_party)
  end

  def test_disable_setting_with_launch_party
    launch_party = Account::LP_FEATURES.last
    is_lp_enabled = @account.send("#{launch_party}_enabled?")
    @account.enable_setting(launch_party)
    @account.disable_setting(launch_party)
    assert_equal @account.send("#{launch_party}_enabled?"), false
  ensure
    is_lp_enabled ? @account.launch(launch_party) : @account.rollback(launch_party)
  end

  def test_enable_setting_with_feature
    feature = Account::BITMAP_FEATURES.last
    is_feature_enabled = @account.send("#{feature}_enabled?")
    @account.revoke_feature(feature)
    assert_equal @account.send("#{feature}_enabled?"), false
    @account.enable_setting(feature)
    assert @account.send("#{feature}_enabled?")
  ensure
    is_feature_enabled ? @account.add_feature(feature) : @account.revoke_feature(feature)
  end

  def test_disable_setting_with_feature
    feature = Account::BITMAP_FEATURES.last
    is_feature_enabled = @account.send("#{feature}_enabled?")
    @account.enable_setting(feature)
    @account.disable_setting(feature)
    assert_equal @account.send("#{feature}_enabled?"), false
  ensure
    is_feature_enabled ? @account.add_feature(feature) : @account.revoke_feature(feature)
  end

  def test_disable_setting_with_invalid_value_doesnt_raise_error
    @account.disable_setting(:abcd)
  end

  def test_admin_setting_for_account_with_setting_dependency_disabled
    feature = :signup_link
    dependent_feature = :basic_settings_feature
    is_dependent_feature_enabled = @account.send("#{dependent_feature}_enabled?")
    @account.revoke_feature(dependent_feature)

    assert_equal @account.admin_setting_for_account?(feature), false
  ensure
    is_dependent_feature_enabled ? @account.add_feature(dependent_feature) : @account.revoke_feature(dependent_feature)
  end

  def test_admin_setting_for_account_with_setting_dependency_enabled
    feature = :signup_link
    dependent_feature = :basic_settings_feature
    is_dependent_feature_enabled = @account.send("#{dependent_feature}_enabled?")
    @account.add_feature(dependent_feature)

    assert_equal @account.admin_setting_for_account?(feature), true
  ensure
    is_dependent_feature_enabled ? @account.add_feature(dependent_feature) : @account.revoke_feature(dependent_feature)
  end

  def test_update_features_method_with_setting_dependency_disabled
    params = { features: { signup_link: false } }

    dependent_feature = :basic_settings_feature
    is_dependent_feature_enabled = @account.send("#{dependent_feature}_enabled?")
    @account.revoke_feature(dependent_feature)

    assert @account.has_feature?(:signup_link), 'signup_link should be true'
    refute @account.has_feature?(dependent_feature), 'dependent_feature should be false'

    @account.update_attributes!(params)

    assert @account.has_feature?(:signup_link), 'signup_link should be true'

    ensure
      is_dependent_feature_enabled ? @account.add_feature(dependent_feature) : @account.revoke_feature(dependent_feature)
  end

  def test_update_features_method_with_setting_dependency_enabled
    params = { features: { signup_link: false } }
    
    feature = :signup_link
    is_feature_enabled = @account.has_feature?(feature)

    dependent_feature = :basic_settings_feature
    is_dependent_feature_enabled = @account.send("#{dependent_feature}_enabled?")
    @account.add_feature(dependent_feature)

    assert @account.has_feature?(feature), 'signup_link should be true'
    assert @account.has_feature?(dependent_feature), 'dependent_feature should be true'

    @account.update_attributes!(params)

    refute @account.has_feature?(:signup_link), 'signup_link should be false'

    ensure
      is_feature_enabled ? @account.add_feature(feature) : @account.revoke_feature(feature)
      is_dependent_feature_enabled ? @account.add_feature(dependent_feature) : @account.revoke_feature(dependent_feature)
  end

  def test_publish_lp_onsignup_as_false
    Account.any_instance.stubs(:signup_in_progress?).returns(false)
    central_publish_lp_stub_const = { feature_name: false }
    feature_class_mapping = {
      feature_name: 'CentralPublishLaunchpartyFeatures'
    }
    stub_const(Account, 'CENTRAL_PUBLISH_LAUNCHPARTY_FEATURES', central_publish_lp_stub_const) do
      stub_const(FeatureClassMapping, 'FEATURE_TO_CLASS_WITH_CENTRAL_FEATURE', feature_class_mapping) do
        @account.launch :feature_name
      end
    end
    # @launch_party_features is set to nil only if the lp publish worker is enqueued
    assert_nil @account.instance_variable_get(:@launch_party_features)
  ensure
    @account.rollback :feature_name
    Account.any_instance.unstub(:signup_in_progress?)
  end

  def test_publish_lp_onsignup_if_preference_of_feature_is_true
    Account.any_instance.stubs(:signup_in_progress?).returns(true)
    central_publish_lp_stub_const = { feature_name: true }
    feature_class_mapping = {
      feature_name: 'CentralPublishLaunchpartyFeatures'
    }
    stub_const(Account, 'CENTRAL_PUBLISH_LAUNCHPARTY_FEATURES', central_publish_lp_stub_const) do
      stub_const(FeatureClassMapping, 'FEATURE_TO_CLASS_WITH_CENTRAL_FEATURE', feature_class_mapping) do
        @account.launch :feature_name
      end
    end

    # @launch_party_features is set to nil only if the lp publish worker is enqueued
    assert_nil @account.instance_variable_get(:@launch_party_features)
  ensure
    Account.any_instance.unstub(:signup_in_progress?)
  end

  def test_publish_lp_onsignup_if_preference_of_feature_is_false
    Account.any_instance.stubs(:signup_in_progress?).returns(true)
    central_publish_lp_stub_const = { feature_name: false }
    feature_class_mapping = {
      feature_name: 'CentralPublishLaunchpartyFeatures'
    }
    stub_const(Account, 'CENTRAL_PUBLISH_LAUNCHPARTY_FEATURES', central_publish_lp_stub_const) do
      stub_const(FeatureClassMapping, 'FEATURE_TO_CLASS_WITH_CENTRAL_FEATURE', feature_class_mapping) do
        @account.launch :feature_name
      end
    end
    assert @account.instance_variable_get(:@launch_party_features).empty?
  ensure
    Account.any_instance.unstub(:signup_in_progress?)
  end
end
