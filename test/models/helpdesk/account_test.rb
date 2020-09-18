require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'test_case_methods.rb')

class AccountTest < ActiveSupport::TestCase
  include AccountTestHelper

  def setup
    @account = Account.first || create_new_account
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
end
