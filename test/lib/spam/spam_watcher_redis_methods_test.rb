# frozen_string_literal: true
require_relative '../../api/unit_test_helper'
['account_test_helper.rb', 'users_test_helper.rb'].each { |file| require Rails.root.join("test/core/helpers/#{file}") }
require 'webmock/minitest'

class SpamWatcherRedisMethodsTest < ActionView::TestCase
  include AccountTestHelper
  include CoreUsersTestHelper

  def setup
    @account = Account.current
    @user = @account.nil? ? create_test_account : add_test_agent(@account)
    User.stubs(:current).returns(@user)
    @account.stubs(:block_spam_user_enabled?).returns(true)
    FreshdeskErrorsMailer.stubs(:deliver_spam_watcher).with({}).returns('email delivered')
    Fdadmin::APICalls.stubs(:make_api_request_to_global).returns(true)
  end

  def teardown
    User.unstub(:current)
    @user.try(&:destroy)
    @account.unstub(:block_spam_user_enabled?)
    FreshdeskErrorsMailer.unstub(:deliver_spam_watcher)
    Fdadmin::APICalls.unstub(:make_api_request_to_global)
  end

  def test_paid_account_agent
    Subscription.any_instance.stubs(:active?).returns(true)
    Subscription.any_instance.stubs(:cmrr).returns(6000)
    @user.stubs(:agent?).returns(true)
    FreshdeskErrorsMailer.expects(:deliver_spam_watcher).never
    SpamWatcherRedisMethods.check_spam(@account, @user, 'helpdesk_tickets')
    assert_equal false, @user.blocked
    Subscription.any_instance.unstub(:cmrr)
    Subscription.any_instance.unstub(:active?)
    @user.unstub(:agent?)
  end

  def test_paid_account_customer
    Subscription.any_instance.stubs(:active?).returns(true)
    Subscription.any_instance.stubs(:cmrr).returns(6000)
    @user.stubs(:agent?).returns(false)
    FreshdeskErrorsMailer.expects(:deliver_spam_watcher).once
    SpamWatcherRedisMethods.check_spam(@account, @user, 'helpdesk_tickets')
    assert_equal false, @user.blocked
    Subscription.any_instance.unstub(:cmrr)
    Subscription.any_instance.unstub(:active?)
    @user.unstub(:agent?)
  end

  def test_active_less_than_5k_mrr_account_agent
    Subscription.any_instance.stubs(:active?).returns(true)
    Subscription.any_instance.stubs(:cmrr).returns(4000)
    @user.stubs(:agent?).returns(true)
    FreshdeskErrorsMailer.expects(:deliver_spam_watcher).once
    SpamWatcherRedisMethods.check_spam(@account, @user, 'helpdesk_tickets')
    assert_equal false, @user.blocked
    Subscription.any_instance.unstub(:cmrr)
    Subscription.any_instance.unstub(:active?)
    @user.unstub(:agent?)
  end

  def test_active_less_than_5k_mrr_account_customer
    Subscription.any_instance.stubs(:active?).returns(true)
    Subscription.any_instance.stubs(:cmrr).returns(4000)
    @user.stubs(:agent?).returns(false)
    FreshdeskErrorsMailer.expects(:deliver_spam_watcher).once
    SpamWatcherRedisMethods.check_spam(@account, @user, 'helpdesk_tickets')
    assert_equal true, @user.blocked
    Subscription.any_instance.unstub(:cmrr)
    Subscription.any_instance.unstub(:active?)
    @user.unstub(:agent?)
  end

  def test_free_account_agent
    Subscription.any_instance.stubs(:free?).returns(true)
    @user.stubs(:agent?).returns(true)
    FreshdeskErrorsMailer.expects(:deliver_spam_watcher).once
    SpamWatcherRedisMethods.check_spam(@account, @user, 'helpdesk_tickets')
    assert_equal false, @user.blocked
    Subscription.any_instance.unstub(:free?)
    @user.unstub(:agent?)
  end

  def test_free_account_customer
    Subscription.any_instance.stubs(:free?).returns(true)
    @user.stubs(:agent?).returns(false)
    FreshdeskErrorsMailer.expects(:deliver_spam_watcher).once
    SpamWatcherRedisMethods.check_spam(@account, @user, 'helpdesk_tickets')
    assert_equal true, @user.blocked
    Subscription.any_instance.unstub(:free?)
    @user.unstub(:agent?)
  end

  def test_trial_account_agent
    Subscription.any_instance.stubs(:free?).returns(false)
    Subscription.any_instance.stubs(:active?).returns(false)
    @user.stubs(:agent?).returns(true)
    FreshdeskErrorsMailer.expects(:deliver_spam_watcher).once
    SpamWatcherRedisMethods.check_spam(@account, @user, 'helpdesk_tickets')
    assert_equal true, @user.blocked
    Subscription.any_instance.unstub(:free?)
    Subscription.any_instance.unstub(:active?)
    @user.unstub(:agent?)
  end

  def test_trial_account_customer
    Subscription.any_instance.stubs(:free?).returns(false)
    Subscription.any_instance.stubs(:active?).returns(false)
    @user.stubs(:agent?).returns(false)
    FreshdeskErrorsMailer.expects(:deliver_spam_watcher).once
    SpamWatcherRedisMethods.check_spam(@account, @user, 'helpdesk_tickets')
    assert_equal true, @user.blocked
    Subscription.any_instance.unstub(:free?)
    Subscription.any_instance.unstub(:active?)
    @user.unstub(:agent?)
  end
end
