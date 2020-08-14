# frozen_string_literal: true

require_relative '../unit_test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
class SwitchToAnnualNotificationTest < ActionView::TestCase
  include AccountTestHelper

  def setup
    @account = Account.first || create_test_account
    Account.stubs(:current).returns(@account)
    Account.any_instance.stubs(:users).returns(Array(User.first))
    User.any_instance.stubs(:privilege?).with(:admin_tasks).returns(true)
  end

  def teardown
    Account.unstub(:current)
    User.any_instance.unstub(:privilege?)
    Account.any_instance.unstub(:users)
    super
  end

  def test_switch_to_annual_notification_test
    Subscription.any_instance.stubs(:active?).returns(true)
    Subscription.any_instance.stubs(:renewal_period).returns(SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:monthly])
    args = { 'account_id' => Account.current.id, 'enqueued_at' => Time.now.to_i }
    assert_nothing_raised do
      response = Ryuken::SwitchToAnnualNotification.new.perform(nil, args)
    end
    admin_user = Account.current.users.find { |user| user.privilege?(:admin_tasks) }
    assert_equal admin_user.agent.show_monthly_to_annual_notification, true
  ensure
    admin_user.agent.update_attribute(:show_monthly_to_annual_notification, false)
    Subscription.any_instance.unstub(:active?)
    Subscription.any_instance.unstub(:renewal_period)
  end

  def test_switch_to_annual_notification_test_trial_account
    Subscription.any_instance.stubs(:active?).returns(false)
    Subscription.any_instance.stubs(:trial?).returns(true)
    args = { 'account_id' => Account.current.id, 'enqueued_at' => Time.now.to_i }
    assert_nothing_raised do
      response = Ryuken::SwitchToAnnualNotification.new.perform(nil, args)
    end
    admin_user = Account.current.users.find { |user| user.privilege?(:admin_tasks) }
    assert_equal admin_user.agent.show_monthly_to_annual_notification, false
  ensure
    admin_user.agent.update_attribute(:show_monthly_to_annual_notification, false)
    Subscription.any_instance.unstub(:active?)
    Subscription.any_instance.unstub(:trial?)
  end

  def test_switch_to_annual_notification_test_annual_billing
    Subscription.any_instance.stubs(:active?).returns(true)
    Subscription.any_instance.stubs(:renewal_period).returns(SubscriptionPlan::BILLING_CYCLE_KEYS_BY_TOKEN[:annual])
    args = { 'account_id' => Account.current.id, 'enqueued_at' => Time.now.to_i }
    assert_nothing_raised do
      response = Ryuken::SwitchToAnnualNotification.new.perform(nil, args)
    end
    admin_user = Account.current.users.find { |user| user.privilege?(:admin_tasks) }
    assert_equal admin_user.agent.show_monthly_to_annual_notification, false
  ensure
    admin_user.agent.update_attribute(:show_monthly_to_annual_notification, false)
    Subscription.any_instance.unstub(:active?)
    Subscription.any_instance.unstub(:renewal_period)
  end

  def test_switch_to_annual_notification_test_exception
    Account.stubs(:current).returns(nil)
    args = { 'account_id' => 1, 'enqueued_at' => Time.now.to_i }
    assert_raises NoMethodError do
      response = Ryuken::SwitchToAnnualNotification.new.perform(nil, args)
    end
  end
end
