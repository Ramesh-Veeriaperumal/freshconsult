require_relative '../unit_test_helper'
require_relative '../../test_transactions_fixtures_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

class WorkerAddDeletedEventTest < ActionView::TestCase
  include Subscription::Events::Constants
  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current  
  end

  def teardown
    Account.unstub(:current)
  end

  def test_worker_add_deleted_event
    @subscription = @account.subscription
    subscription_event_count = @account.subscription_events.count
    args = {}
    deleted_event_account_id = @subscription.account_id
    Subscriptions::AddDeletedEvent.new.perform(args)
    created_record = @account.subscription_events.last
    assert_equal created_record.account_id, deleted_event_account_id
    assert_equal subscription_event_count + 1, Account.current.subscription_events.count
  end

  def test_add_deleted_event_with_invalid_arguments
    assert_nothing_raised do
      args = {}
      Subscriptions::AddDeletedEvent.any_instance.stubs(:subscription_info).raises(StandardError)
      Subscriptions::AddDeletedEvent.new.perform(args)
    end
  ensure
    Subscriptions::AddDeletedEvent.unstub(:subscription_info)
  end
end
