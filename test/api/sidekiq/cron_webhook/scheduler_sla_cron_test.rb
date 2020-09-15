require_relative '../../../../test/api/unit_test_helper'
require_relative '../../../test_transactions_fixtures_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
Sidekiq::Testing.fake!
class SchedulerSlaCronTest < ActionView::TestCase
  include AccountTestHelper

  def setup
    create_test_account if Account.first.nil?
    Account.stubs(:current).returns(Account.first)
    Subscription.any_instance.stubs(:switch_annual_notification_eligible?).returns(false)
    @account = Account.current
  end

  def teardown
    Subscription.any_instance.unstub(:switch_annual_notification_eligible?)
    super
  end

  def test_trail_sla_scheduler
    Admin::Sla::Reminder::Trial.drain
    old_state = @account.subscription.state
    Account.any_instance.stubs(:sla_management_enabled?).returns(true)
    change_account_state(Subscription::TRIAL, @account) unless @account.subscription.trial?
    CronWebhooks::SchedulerSlaReminder.new.perform(type: 'trial', task_name: 'scheduler_sla_reminder')
    assert_equal true, Admin::Sla::Reminder::Trial.jobs.size >= 1, 'should enqueue trial workers'
  ensure
    change_account_state(old_state, @account)
  end

  def test_sla_scheduler_paid
    Admin::Sla::Reminder::Base.drain
    old_state = @account.subscription.state
    Account.any_instance.stubs(:sla_management_enabled?).returns(true)
    change_account_state(Subscription::ACTIVE, @account) unless @account.subscription.active?
    CronWebhooks::SchedulerSlaReminder.new.perform(type: 'paid', task_name: 'scheduler_sla_reminder')
    assert_equal true, Admin::Sla::Reminder::Base.jobs.size >= 1, 'should enqueue paid workers'
  ensure
    change_account_state(old_state, @account)
  end

  def test_sla_scheduler_premium
    Admin::Sla::Reminder::Premium.drain
    old_state = @account.subscription.state
    Account.any_instance.stubs(:sla_management_enabled?).returns(true)
    @account.premium = 1
    @account.save
    change_account_state(Subscription::ACTIVE, @account) unless @account.subscription.active?
    CronWebhooks::SchedulerSlaReminder.new.perform(type: 'premium', task_name: 'scheduler_sla_reminder')
    assert_equal true, Admin::Sla::Reminder::Premium.jobs.size >= 1, 'should enqueue Premium workers'
  ensure
    change_account_state(old_state, @account)
    @account.premium = 0
    @account.save
  end

  def test_trail_sla_escalation
    Admin::Sla::Escalation::Trial.drain
    old_state = @account.subscription.state
    Account.any_instance.stubs(:sla_management_enabled?).returns(true)
    change_account_state(Subscription::TRIAL, @account) unless @account.subscription.trial?
    CronWebhooks::SchedulerSla.new.perform(type: 'trial', task_name: 'scheduler_sla')
    assert_equal true, Admin::Sla::Escalation::Trial.jobs.size >= 1, 'should enqueue trial workers'
  ensure
    change_account_state(old_state, @account)
  end

  def test_sla_escalation_paid
    Admin::Sla::Escalation::Base.drain
    old_state = @account.subscription.state
    Account.any_instance.stubs(:sla_management_enabled?).returns(true)
    change_account_state(Subscription::ACTIVE, @account) unless @account.subscription.active?
    CronWebhooks::SchedulerSla.new.perform(type: 'paid', task_name: 'scheduler_sla')
    assert_equal true, Admin::Sla::Escalation::Base.jobs.size >= 1, 'should enqueue paid workers'
  ensure
    change_account_state(old_state, @account)
  end

  def test_sla_escalation_premium
    Admin::Sla::Escalation::Premium.drain
    old_state = @account.subscription.state
    Account.any_instance.stubs(:sla_management_enabled?).returns(true)
    @account.premium = 1
    @account.save
    change_account_state(Subscription::ACTIVE, @account) unless @account.subscription.active?
    CronWebhooks::SchedulerSla.new.perform(type: 'premium', task_name: 'scheduler_sla')
    assert_equal true, Admin::Sla::Escalation::Premium.jobs.size >= 1, 'should enqueue Premium workers'
  ensure
    change_account_state(old_state, @account)
    @account.premium = 0
    @account.save
  end
end
