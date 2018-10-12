require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'minitest/autorun'
Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class RemoveRestrictionsWorkerTest < ActionView::TestCase

  include AccountTestHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_account_remove_restriction_worker
    assert_nothing_raised do
      assert_not_equal Account.current.email_notifications.select{|n| n.visible_to_agent? && n.notification_type != EmailNotification::NEW_TICKET && !n.agent_notification}.size, 0
      assert_not_equal Account.current.account_va_rules.with_send_email_actions.select{ |action| !action.active}.size, 0
      AccountActivation::RemoveRestrictionsWorker.new.perform({})
      assert_equal Account.current.email_notifications.select{|n| n.visible_to_agent? && n.notification_type != EmailNotification::NEW_TICKET && !n.agent_notification}.size, 0
      assert_equal Account.current.account_va_rules.with_send_email_actions.select{ |action| !action.active}.size, 0
    end
  end


  def test_account_remove_restriction_worker_exception
    assert_raises(RuntimeError) do
      AccountActivation::RemoveRestrictionsWorker.any_instance.stubs(:activate_notifications).raises(RuntimeError)
      AccountActivation::RemoveRestrictionsWorker.new.perform({})
    end
  ensure
    AccountActivation::RemoveRestrictionsWorker.any_instance.unstub(:activate_notifications)
  end
end