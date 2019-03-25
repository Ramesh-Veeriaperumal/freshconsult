require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'minitest/autorun'
Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'forums_test_helper.rb')

class ClearModerationRecordsTest < ActionView::TestCase
  include AccountTestHelper
  include CoreForumsTestHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @user = create_dummy_customer
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_worker_for_topic
    assert_nothing_raised do
      category = create_test_category
      forum = create_test_forum(category)
      topic = create_test_topic(forum, @user)
      Community::ClearModerationRecords.new.perform(topic.id, topic.class.to_s)
    end
  end

  def test_worker_for_forum
    assert_nothing_raised do
      category = create_test_category
      @forum = create_test_forum(category)
      create_test_topic(@forum, @user)
      create_test_topic(@forum, @user)
      topic_ids = @forum.topics.pluck(:id)
      ForumUnpublished.stubs(:last_month).returns(simple_forum_dynamo_response('ForumUnpublished')).then.returns(simple_forum_empty_dynamo_response('ForumUnpublished'))
      ForumSpam.stubs(:last_month).returns(simple_forum_dynamo_response('ForumSpam')).then.returns(simple_forum_empty_dynamo_response('ForumSpam'))
      Community::ClearModerationRecords.new.perform(@forum.id, @forum.class.to_s, topic_ids)
    end
  ensure
    ForumUnpublished.unstub(:last_month)
    ForumSpam.unstub(:last_month)
  end

  private

    def simple_forum_query_response
      { member: [
        { 'body_html' => { s: "<div dir=\"ltr\"><p>test topic 1</p>\n</div>" }, 'forum_id' => { n: @forum.id }, 'inline_attachment_ids' => { s: '[]' }, 'timestamp' => { n: '1535450680.078502' }, 'marked_by_filter' => { n: '0' }, 'cloud_file_attachments' => { s: '[]' }, 'attachments' => { s: '{}' }, 'portal' => { n: '1' }, 'account_id' => { n: '1' }, 'user_timestamp' => { n: '215354506800785020' }, 'title' => { s: 'test topic created by selva' } }
      ],
        count: 1,
        scanned_count: 1 }
    end

    def simple_forum_dynamo_response(spamscope)
      Dynamo::Collection.new(simple_forum_query_response, spamscope)
    end

    def simple_forum_empty_dynamo_response(spamscope)
      Dynamo::Collection.new({ member: [],
                               count: 0,
                               scanned_count: 0 }, spamscope)
    end
end
