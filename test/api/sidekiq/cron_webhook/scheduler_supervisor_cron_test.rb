require_relative '../../../../test/api/unit_test_helper'
require_relative '../../../test_transactions_fixtures_helper'
require 'sidekiq/testing'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
Sidekiq::Testing.fake!
class SchedulerSupervisorCronTest < ActionView::TestCase
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

  def test_trail_supervisor_scheduler
    Admin::TrialSupervisorWorker.drain
    old_state = @account.subscription.state
    Account.any_instance.stubs(:supervisor_enabled?).returns(true)
    Account.any_instance.stubs(:supervisor_rules).returns(['rules'])
    change_account_state(Subscription::TRIAL, @account) unless @account.subscription.trial?
    CronWebhooks::SchedulerSupervisor.new.perform(type: 'trial', task_name: 'scheduler_supervisor')
    assert_equal true, Admin::TrialSupervisorWorker.jobs.size >= 1, 'should enqueue trial workers'
  ensure
    change_account_state(old_state, @account)
    Account.any_instance.unstub(:supervisor_enabled?)
    Account.any_instance.unstub(:supervisor_rules)
  end

  def test_supervisor_scheduler_paid
    Admin::SupervisorWorker.drain
    old_state = @account.subscription.state
    Account.any_instance.stubs(:supervisor_enabled?).returns(true)
    Account.any_instance.stubs(:supervisor_rules).returns(['rules'])
    change_account_state(Subscription::ACTIVE, @account) unless @account.subscription.active?
    CronWebhooks::SchedulerSupervisor.new.perform(type: 'paid', task_name: 'scheduler_supervisor')
    assert_equal true, Admin::SupervisorWorker.jobs.size >= 1, 'should enqueue paid workers'
  ensure
    change_account_state(old_state, @account)
    Account.any_instance.unstub(:supervisor_enabled?)
    Account.any_instance.unstub(:supervisor_rules)
  end

  def test_supervisor_scheduler_premium
    Admin::PremiumSupervisorWorker.drain
    old_state = @account.subscription.state
    Account.any_instance.stubs(:supervisor_enabled?).returns(true)
    Account.any_instance.stubs(:supervisor_rules).returns(['rules'])
    @account.premium = 1
    @account.save
    change_account_state(Subscription::ACTIVE, @account) unless @account.subscription.active?
    CronWebhooks::SchedulerSupervisor.new.perform(type: 'premium', task_name: 'scheduler_supervisor')
    assert_equal true, Admin::PremiumSupervisorWorker.jobs.size >= 1, 'should enqueue Premium workers'
  ensure
    change_account_state(old_state, @account)
    @account.premium = 0
    @account.save
    change_account_state(old_state, @account)
    Account.any_instance.unstub(:supervisor_enabled?)
    Account.any_instance.unstub(:supervisor_rules)
  end
end
