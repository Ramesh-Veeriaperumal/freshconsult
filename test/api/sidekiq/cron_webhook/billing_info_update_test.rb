require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

Sidekiq::Testing.fake!

class BillingInfoUpdateTest < ActionView::TestCase
  include AccountTestHelper
  include CoreUsersTestHelper

  def setup
    super
    before_all
  end

  def before_all
    @account = Account.current
    @user = @account.nil? ? create_test_account : add_new_user(@account)
    @user.make_current
    Account.stubs(:paid_accounts).returns(Account)
    Account.current.rollback(:update_billing_info)
  end

  def teardown
    Account.unstub(:paid_accounts)
  end

  def test_billing_info_udpate_without_allow_billing_info_update
    account_id = Account.current.id
    Account.any_instance.stubs(:all_launched_features).returns([])
    AccountAdditionalSettings.any_instance.stubs(:additional_settings).returns(nil)
    CronWebhooks::BillingInfoUpdate.new.perform(task_name: 'billing_info_enable_billing_info_update')
    Account.any_instance.unstub(:all_launched_features)
    AccountAdditionalSettings.any_instance.unstub(:additional_settings)
    Account.find(account_id).make_current
    assert_equal false, Account.current.launched?(:update_billing_info)
  end

  def test_billing_info_udpate_with_allow_billing_info_update
    account_id = Account.current.id
    Account.any_instance.stubs(:all_launched_features).returns([:allow_billing_info_update])
    AccountAdditionalSettings.any_instance.stubs(:additional_settings).returns(nil)
    CronWebhooks::BillingInfoUpdate.new.perform(task_name: 'billing_info_enable_billing_info_update')
    Account.any_instance.unstub(:all_launched_features)
    AccountAdditionalSettings.any_instance.unstub(:additional_settings)
    Account.find(account_id).make_current
    assert Account.current.launched?(:update_billing_info)
  end
end
