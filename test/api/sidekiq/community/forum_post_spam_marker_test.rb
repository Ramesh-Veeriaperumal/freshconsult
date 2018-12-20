require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'minitest/autorun'
Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'forums_test_helper.rb')
require Rails.root.join('spec', 'support', 'forum_dynamo_helper.rb')

class ForumPostSpamMarkerTest < ActionView::TestCase
  include AccountTestHelper
  include ForumsTestHelper
  include ForumDynamoHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @user = create_dummy_customer
    @category = create_test_category
    @forum = create_test_forum(@category)
    @topic = create_test_topic(@forum, @user)
    post = create_test_post(@topic, false, @user)
  end

  def teardown
    @category.destroy
    Account.unstub(:current)
    super
  end

  def test_forum_post_spam_marker_worker
    assert_nothing_raised do
      Community::ForumPostSpamMarker.new.perform(topic_ids: [@topic.id])
      assert @forum.topics.empty?, 'Topic should be destroyed'
    end
  end

  def test_forum_post_spam_marker_worker_with_exception_for_a_topic
    assert_nothing_raised do
      Community::ForumPostSpamMarker.any_instance.stubs(:create_dynamo_post).raises(RuntimeError)
      Community::ForumPostSpamMarker.new.perform(topic_ids: [@topic.id])
    end
  ensure
    Community::ForumPostSpamMarker.any_instance.unstub(:create_dynamo_post)
  end

  def test_forum_post_spam_marker_worker_with_exception
    assert_nothing_raised do
      Account.any_instance.stubs(:topics).raises(RuntimeError)
      Community::ForumPostSpamMarker.new.perform(topic_ids: [@topic.id])
    end
  ensure
    Account.any_instance.unstub(:topics)
  end
end
