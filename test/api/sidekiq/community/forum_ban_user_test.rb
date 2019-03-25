require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'minitest/autorun'
Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'forums_test_helper.rb')
require Rails.root.join('spec', 'support', 'forum_dynamo_helper.rb')

class ForumBanUserTest < ActionView::TestCase

  include AccountTestHelper
  include CoreForumsTestHelper
  include ForumDynamoHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @user = create_dummy_customer
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_ban_user_worker
    assert_nothing_raised do
      category = create_test_category
      forum = create_test_forum(category)
      topic = create_test_topic(forum, @user)
      post = create_test_post(topic, false, @user)
      assert !@user.reload.posts.empty?
      ForumUnpublished.stubs(:by_user).returns(simple_forum_unpublished_dynamo_response).then.returns(simple_forum_empty_unpublished_dynamo_response)
      Community::ForumBanUser.new.perform({ spam_user_id: @user.id })
      assert @user.reload.posts.empty?, "All posts by this user should be destroyed"
      category.destroy
    end
  ensure
    ForumUnpublished.unstub(:by_user)
  end


  def test_ban_user_worker_with_exception
    assert_nothing_raised do
      Community::ForumBanUser.any_instance.stubs(:ban_posts_dynamo).raises(RuntimeError)
      Community::ForumBanUser.new.perform({ spam_user_id: @user.id })
    end
  ensure
    Community::ForumBanUser.any_instance.unstub(:ban_posts_dynamo)
  end

  private

  def simple_forum_unpublished_query_response
    { :member => [
        { "body_html" => { :s => "<div dir=\"ltr\"><p>test topic</p>\n</div>" }, "forum_id" => { :n => "3" }, "inline_attachment_ids" => { :s => "[]" }, "timestamp" => { :n => "1535450680.078502" }, "marked_by_filter" => { :n => "0" }, "cloud_file_attachments" => { :s => "[]" }, "attachments" => { :s => "{}" }, "portal" => { :n => "1" }, "account_id" => { :n => "1" }, "user_timestamp" => { :n => "215354506800785020" }, "title" => { :s => "test topic created by selva" } },
        { "body_html" => { :s => "<div dir=\"ltr\"><p>test</p>\n</div>" }, "forum_id" => { :n => "3" }, "inline_attachment_ids" => { :s => "[]" }, "timestamp" => { :n => "1535450718.297905" }, "marked_by_filter" => { :n => "0" }, "cloud_file_attachments" => { :s => "[]" }, "attachments" => { :s => "{}" }, "portal" => { :n => "1" }, "account_id" => { :n => "1" }, "user_timestamp" => { :n => "215354507182979040" }, "title" => { :s => "test topic" } }
    ],
      :count => 2,
      :scanned_count => 2
    }
  end

  def simple_forum_unpublished_dynamo_response
    Dynamo::Collection.new(simple_forum_unpublished_query_response, 'ForumUnpublished')
  end

  def simple_forum_empty_unpublished_dynamo_response
    Dynamo::Collection.new({ :member => [],
                             :count => 0,
                             :scanned_count => 0
                           }, 'ForumUnpublished')
  end
end