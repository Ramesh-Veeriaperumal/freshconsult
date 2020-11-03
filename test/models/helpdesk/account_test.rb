require_relative '../test_helper'
require Rails.root.join('spec', 'support', 'account_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'test_case_methods.rb')

class AccountTest < ActiveSupport::TestCase
  include AccountHelper

  def setup
    @account = Account.first || create_test_account
    @account.make_current
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

  def test_update_features_method_with_setting_dependency_disabled
    params = { features: { signup_link: true } }

    dependent_feature = :basic_settings_feature
    is_dependent_feature_enabled = @account.has_feature?(dependent_feature)

    setting = :signup_link
    @account.add_feature(dependent_feature)
    @account.disable_setting(setting)

    @account.revoke_feature(dependent_feature)

    refute @account.has_feature?(setting), 'setting should be false'
    refute @account.has_feature?(dependent_feature), 'dependent_feature should be false'

    assert_raise RuntimeError do
      @account.update_attributes!(params)
      refute @account.has_feature?(setting), 'setting should be false'
    end
  ensure
    is_dependent_feature_enabled ? @account.add_feature(dependent_feature) : @account.revoke_feature(dependent_feature)
  end

  def test_update_features_method_with_setting_dependency_enabled
    params = { features: { signup_link: true } }

    dependent_feature = :basic_settings_feature
    is_dependent_feature_enabled = @account.has_feature?(dependent_feature)
    @account.add_feature(dependent_feature)

    setting = :signup_link
    is_setting_enabled = @account.has_feature?(setting)
    @account.disable_setting(setting)

    refute @account.has_feature?(setting), 'setting should be false'
    assert @account.has_feature?(dependent_feature), 'dependent_feature should be true'

    @account.update_attributes!(params)

    assert @account.has_feature?(setting), 'setting should be true'
  ensure
    is_setting_enabled ? @account.enable_setting(setting) : @account.disable_setting(setting)
    is_dependent_feature_enabled ? @account.add_feature(dependent_feature) : @account.revoke_feature(dependent_feature)
  end

  def test_publish_lp_onsignup_as_false
    Account.any_instance.stubs(:signup_in_progress?).returns(false)
    central_publish_lp_stub_const = { feature_name: false }
    feature_class_mapping = {
      feature_name: 'CentralPublishLaunchpartyFeatures'
    }
    stub_const(Account, 'CENTRAL_PUBLISH_LAUNCHPARTY_FEATURES', central_publish_lp_stub_const) do
      stub_const(FeatureClassMapping, 'FEATURE_TO_CLASS', feature_class_mapping) do
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
      @account.launch :feature_name
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
      @account.launch :feature_name
    end
    assert @account.instance_variable_get(:@launch_party_features).empty?
  ensure
    Account.any_instance.unstub(:signup_in_progress?)
  end

  def test_enqueue_vault_account_worker_when_secure_fields_enabled
    Account.current.stubs(:secure_fields_toggle_enabled?).returns(true)
    secure_fields_feature_presence = @account.secure_fields_enabled?
    @account.disable_setting(:secure_fields)
    ::Vault::AccountWorker.jobs.clear
    @account.enable_setting(:secure_fields)
    assert_equal 1, ::Vault::AccountWorker.jobs.size
    args = ::Vault::AccountWorker.jobs.first.deep_symbolize_keys[:args][0]
    assert_equal 'update', args[:action]
  ensure
    @account.disable_setting(:secure_fields) unless secure_fields_feature_presence
    Account.current.unstub(:secure_fields_toggle_enabled?)
    ::Vault::AccountWorker.jobs.clear
  end

  def test_enqueue_vault_account_worker_when_secure_fields_disabled
    Account.current.stubs(:secure_fields_toggle_enabled?).returns(true)
    secure_fields_feature_presence = @account.secure_fields_enabled?
    @account.enable_setting(:secure_fields)
    ::Vault::AccountWorker.jobs.clear
    @account.disable_setting(:secure_fields)
    assert_equal 1, ::Vault::AccountWorker.jobs.size
    args = ::Vault::AccountWorker.jobs.first.deep_symbolize_keys[:args][0]
    assert_equal 'delete', args[:action]
  ensure
    @account.enable_setting(:secure_fields) if secure_fields_feature_presence
    Account.current.unstub(:secure_fields_toggle_enabled?)
    ::Vault::AccountWorker.jobs.clear
  end
end
