# frozen_string_literal: true

require_relative '../unit_test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'models', 'helpers', 'subscription_test_helper.rb')
require 'sidekiq/testing'
Sidekiq::Testing.fake!

class FreddyConsumedSessionReminderTest < ActionView::TestCase
  include AccountTestHelper
  include SubscriptionTestHelper

  def test_freddy_consumed_session_reminder
    Account.stubs(:current).returns(Account.first)
    Subscription.any_instance.stubs(:freddy_sessions).returns(1000)
    ::Bot::Emailbot::FreddyConsumedSessionWorker.jobs.clear
    session_payload = { data: { payload: { model_properties: { productAccountId: Account.current.id, sessionsConsumed: 50, consumedPercentage: 80 } } } }
    sqs_msg = Hashit.new(body: session_payload.to_json)
    assert_nothing_raised do
      Ryuken::FreddyConsumedSessionReminder.new.perform(sqs_msg, nil)
    end
    sidekiq_jobs = Bot::Emailbot::FreddyConsumedSessionWorker.jobs
    assert sidekiq_jobs.count == 1
  ensure
    Subscription.any_instance.unstub(:freddy_sessions)
    Account.any_instance.unstub(:current)
  end

  def test_freddy_consumed_session_reminder_bundle_account
    Account.stubs(:current).returns(Account.first)
    Subscription.any_instance.stubs(:freddy_sessions).returns(1000)
    ::Bot::Emailbot::FreddyConsumedSessionWorker.jobs.clear
    session_payload = { data: { payload: { model_properties: { 'bundleType': 'SUPPORT360', 'anchorProductAccountId': Account.current.id, sessionsConsumed: 50, consumedPercentage: 80 } } } }
    sqs_msg = Hashit.new(body: session_payload.to_json)
    assert_nothing_raised do
      Ryuken::FreddyConsumedSessionReminder.new.perform(sqs_msg, nil)
    end
    sidekiq_jobs = Bot::Emailbot::FreddyConsumedSessionWorker.jobs
    assert sidekiq_jobs.count == 1
  ensure
    Subscription.any_instance.unstub(:freddy_sessions)
    Account.any_instance.unstub(:current)
  end

  def test_freddy_consumed_session_reminder_when_breach_occures
    Account.stubs(:current).returns(Account.first)
    Subscription.any_instance.stubs(:freddy_sessions).returns(1000)
    ::Bot::Emailbot::FreddyConsumedSessionWorker.jobs.clear
    session_payload = { data: { payload: { model_properties: { productAccountId: Account.current.id, sessionsConsumed: 40, consumedPercentage: 100 } } } }
    sqs_msg = Hashit.new(body: session_payload.to_json)
    assert_nothing_raised do
      Ryuken::FreddyConsumedSessionReminder.new.perform(sqs_msg, nil)
    end
    sidekiq_jobs = Bot::Emailbot::FreddyConsumedSessionWorker.jobs
    assert sidekiq_jobs.count == 3
  ensure
    Subscription.any_instance.unstub(:freddy_sessions)
    Account.any_instance.unstub(:current)
  end

  def test_freddy_consumed_session_reminder_when_no_session_is_present
    Account.stubs(:current).returns(Account.first)
    ::Bot::Emailbot::FreddyConsumedSessionWorker.jobs.clear
    Subscription.any_instance.stubs(:freddy_sessions).returns(0)
    session_payload = { data: { payload: { model_properties: { productAccountId: Account.current.id, sessionsConsumed: 40, consumedPercentage: 100 } } } }
    sqs_msg = Hashit.new(body: session_payload.to_json)
    assert_nothing_raised do
      Ryuken::FreddyConsumedSessionReminder.new.perform(sqs_msg, nil)
    end
    sidekiq_jobs = Bot::Emailbot::FreddyConsumedSessionWorker.jobs
    assert sidekiq_jobs.count.zero?
  ensure
    Subscription.any_instance.unstub(:freddy_sessions)
    Account.any_instance.unstub(:current)
  end

  def test_freddy_consumed_session_reminder_when_exception_occures
    Account.stubs(:current).returns(Account.first)
    Subscription.any_instance.stubs(:freddy_sessions).returns(1000)
    Bot::Emailbot::FreddyConsumedSessionWorker.stubs(:perform_async).raises(StandardError)
    session_payload = { data: { payload: { model_properties: { productAccountId: Account.current.id, sessionsConsumed: 40, consumedPercentage: 100 } } } }
    sqs_msg = Hashit.new(body: session_payload.to_json)
    assert_raises StandardError do
      Ryuken::FreddyConsumedSessionReminder.new.perform(sqs_msg, nil)
    end
  ensure
    Subscription.any_instance.unstub(:freddy_sessions)
    Account.any_instance.unstub(:current)
    Bot::Emailbot::FreddyConsumedSessionWorker.unstub(:perform_async)
  end

  def test_freddy_autorecharge
    Account.stubs(:current).returns(Account.first)
    Subscription.any_instance.stubs(:freddy_sessions).returns(1000)
    Subscription.any_instance.stubs(:freddy_auto_recharge_enabled?).returns(true)
    Subscription.any_instance.stubs(:freddy_auto_recharge_packs).returns(5)
    ChargeBee::Invoice.stubs(:charge_addon).returns(true)
    session_payload = { data: { payload: { model_properties: { productAccountId: Account.current.id, auto_recharge_threshold_reached: true } } } }
    sqs_msg = Hashit.new(body: session_payload.to_json)
    assert_nothing_raised do
      Ryuken::FreddyConsumedSessionReminder.new.perform(sqs_msg, nil)
    end
  ensure
    Subscription.any_instance.unstub(:freddy_sessions)
    Subscription.any_instance.unstub(:freddy_auto_recharge_enabled?)
    Subscription.any_instance.unstub(:freddy_auto_recharge_packs)
    Account.any_instance.unstub(:current)
    ChargeBee::Invoice.unstub(:charge_addon)
  end
end
