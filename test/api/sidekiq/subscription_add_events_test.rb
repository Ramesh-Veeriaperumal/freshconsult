require_relative '../unit_test_helper'
require_relative '../../test_transactions_fixtures_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

class SubscriptionAddEventsTest < ActionView::TestCase
  include Subscription::Events::Constants

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current 
  end

  def teardown
    Account.unstub(:current)
  end

  def test_create_new_subscription_event
    @subscription_events_count = @account.subscription_events.count
    args = { 'subscription_hash' => { 'amount' => 0, 'state' => STATES[:active] } }
    @subscription = @account.subscription
    @subscription.state = 'active'
    SubscriptionEvent.stubs(:update_record?).returns(false)
    Subscriptions::SubscriptionAddEvents.new.perform(args)
    assert_equal @subscription_events_count + 1, @account.subscription_events.count
  ensure
    SubscriptionEvent.unstub(:update_record?)
  end

  def test_update_subscription_event
    @subscription_events_count = @account.subscription_events.count
    @subscription = @account.subscription
    @subscription.state = 'active'
    args = { 'subscription_hash' => { 'amount' => 0, 'state' => STATES[:active] } }
    SubscriptionEvent.stubs(:update_record?).returns(true)
    Subscriptions::SubscriptionAddEvents.new.perform(args)
    assert_equal @subscription_events_count, @account.subscription_events.count
  ensure
    SubscriptionEvent.unstub(:update_record?)
  end

  def test_subscription_event_with_invalid_arguments
    assert_nothing_raised do
      args = { 'subscription_hash' => ['amount' => 0, 'state' => STATES[:trial]] }
      Subscriptions::SubscriptionAddEvents.any_instance.stubs(:assign_event_attributes).raises(StandardError)
      Subscriptions::SubscriptionAddEvents.new.perform(args)
    end
  ensure
    Subscriptions::SubscriptionAddEvents.unstub(:assign_event_attributes)
  end
end
