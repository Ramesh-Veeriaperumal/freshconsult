require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

class FreddyConsumedSessionWorkerTest < ActionView::TestCase
  def setup
    Account.stubs(:current).returns(Account.first)
  end

  def teardown
    Account.unstub(:current)
  end

  def test_freddy_consumed_session_worker
    FreddyConsumedSessionMailer.expects(:send_consumed_session_remainder).once
    assert_nothing_raised do
      Sidekiq::Testing.inline! do
        Bot::Emailbot::FreddyConsumedSessionWorker.new.perform(sessions_consumed: 50, sessions_count: 400)
      end
    end
  end

  def test_freddy_consumed_session_worker_with_exception
    Account.unstub(:current)
    assert_raises StandardError do
      Sidekiq::Testing.inline! do
        Account.stubs(:current).raises(StandardError)
        Bot::Emailbot::FreddyConsumedSessionWorker.new.perform(sessions_consumed: 50, sessions_count: 400)
      end
    end
  ensure
    FreddyConsumedSessionMailer.any_instance.unstub(:send_consumed_session_remainder)
  end
end
