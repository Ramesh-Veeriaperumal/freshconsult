require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'minitest/autorun'
Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'users_test_helper.rb')

class DispatchSpamDigestTest < ActionView::TestCase
  include CoreUsersTestHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @agent = add_test_agent(@account)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_worker
    assert_nothing_raised do
      create_moderator
      SpamCounter.stubs(:elaborate_count).with('unpublished').returns(count_response(1))
      SpamCounter.stubs(:elaborate_count).with('spam').returns(count_response(1))
      Community::DispatchSpamDigest.new.perform
    end
  ensure
    SpamCounter.unstub(:elaborate_count)
  end

  def test_worker_with_false_can_send_approval_digest
    assert_nothing_raised do
      create_moderator
      Account.any_instance.stubs(:features_included?).with(:moderate_all_posts).returns(false)
      Account.any_instance.stubs(:features_included?).with(:moderate_posts_with_links).returns(false)
      SpamCounter.stubs(:elaborate_count).with('unpublished').returns(count_response(0))
      SpamCounter.stubs(:elaborate_count).with('spam').returns(count_response(0))
      Community::DispatchSpamDigest.new.perform
    end
  ensure
    SpamCounter.unstub(:elaborate_count)
    Account.any_instance.unstub(:features_included?)
  end

  def test_worker_with_exception
    assert_nothing_raised do
      create_moderator
      SpamCounter.stubs(:elaborate_count).raises(RuntimeError)
      Community::DispatchSpamDigest.new.perform
    end
  ensure
    SpamCounter.unstub(:elaborate_count)
  end

  private

    def create_moderator
      @forum_moderator = FactoryGirl.build(:forum_moderator, account_id: @account.id, moderator_id: @agent.id)
    end

    def count_response(count)
      { 'topics' => count, 'posts' => count }
    end
end
