require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
['user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'discussions_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')

class MergeTopicsWorkerTest < ActionView::TestCase
  include AccountTestHelper
  include DiscussionsTestHelper
  include ControllerTestHelper
  include UsersHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @agent = get_admin
    @customer = create_dummy_customer
    @agent.make_current
    @source_topic = create_test_topic(Forum.first)
    @target_topic = create_test_topic(Forum.first)
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_merge_topics_worker
    set_assertion_counts
    TopicMailer.stubs(:deliver_topic_merge_email).returns(nil)
    Community::MergeTopicsWorker.new.perform(source_topic_ids: [@source_topic.id], target_topic_id: @target_topic.id, source_note: 'Test')
    assert_equal @activity_count+2, @account.activities.count
    assert_equal @topic_posts_count+1, @source_topic.posts.count
    assert_equal @target_monitors_count+1, @target_topic.monitorships.active_monitors.count
    assert_equal @target_votes_count+1, @target_topic.votes.count
  ensure
    TopicMailer.unstub(:deliver_topic_merge_email)
  end

  def test_merge_topics_worker_with_empty_note
    set_assertion_counts
    TopicMailer.stubs(:deliver_topic_merge_email).returns(nil)
    Community::MergeTopicsWorker.new.perform(source_topic_ids: [@source_topic.id], target_topic_id: @target_topic.id, source_note: '<p></p>')
    assert_equal @activity_count+1, @account.activities.count
    assert_equal @topic_posts_count, @source_topic.posts.count
    assert_equal @target_monitors_count+1, @target_topic.monitorships.active_monitors.count
    assert_equal @target_votes_count+1, @target_topic.votes.count
  ensure
    TopicMailer.unstub(:deliver_topic_merge_email)
  end

  def test_merge_topics_worker_with_exception_handled
    assert_nothing_raised do
      Account.any_instance.stubs(:topics).raises(RuntimeError)
      Community::MergeTopicsWorker.new.perform(source_topic_ids: [@source_topic.id], target_topic_id: @target_topic.id, source_note: '<p></p>')
    end
  ensure
    Account.any_instance.unstub(:topics)
  end

  private

    def set_assertion_counts
      source_user = add_new_user(@account)
      monitor_topic(@source_topic, source_user, @account.main_portal.id)
      vote_topic(@source_topic, source_user)
      target_user = add_new_user(@account)
      monitor_topic(@target_topic, target_user, @account.main_portal.id)
      vote_topic(@target_topic, target_user)
      @target_monitors_count = @target_topic.monitorships.active_monitors.count
      @target_votes_count = @target_topic.votes.count
      @activity_count = @account.activities.count
      @topic_posts_count = @source_topic.posts.count
    end

end