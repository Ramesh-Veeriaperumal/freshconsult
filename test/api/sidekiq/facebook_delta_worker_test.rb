require_relative '../unit_test_helper'
require_relative '../../test_transactions_fixtures_helper'
require 'sidekiq/testing'

Sidekiq::Testing.fake!

require Rails.root.join('test', 'api', 'helpers', 'social_test_helper.rb')

class FacebookDeltaTest < ActionView::TestCase
  include SocialTestHelper

  def teardown
    Social::FacebookPage.any_instance.stubs(:unsubscribe_realtime).returns(true)
    super
    @account.facebook_pages.delete_all
    @account.facebook_streams.delete_all
    @account.tickets.where(source: Account.current.helpdesk_sources.ticket_source_keys_by_token[:facebook]).destroy_all
    Account.unstub(:current)
  ensure
    Social::FacebookPage.any_instance.unstub(:unsubscribe_realtime)
  end

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @fb_page = create_facebook_page
    @user_id = rand(10**10)
  end

  def facebook_feed_hash(page_id, timestamp, message)
    query_options = {
      'page_id' => page_id.to_s,
      'timestamp' => timestamp.to_s,
      'feed' => message.to_s
    }
  end

  def test_add_feeds_to_sqs_feeds_blank
    args = { 'page_id' => @fb_page.page_id, 'discard_feed' => true }
    @method_call_count = 0
    sqs_instance = AWS::SQS::Queue.new("{}")
    sqs_instance.stub :send_message, -> {@method_call_count += 1; true } do
      Social::DynamoHelper.stubs(:query).returns([])
      Social::FacebookDelta.new.perform(args)
    end
    assert_equal @method_call_count,0
  ensure
    Social::DynamoHelper.unstub(:query)
    sqs_instance.unstub :send_message
  end

  def test_add_feeds_to_sqs_with_fb_page_invalid
    @method_call_count = 0
    sqs_instance = AWS::SQS::Queue.new("{}")
    sqs_instance.stub :send_message, -> {@method_call_count += 1; true } do
      Social::FacebookPage.any_instance.stubs(:valid_page?).returns(false)
      args = { 'page_id' => @fb_page.page_id, 'discard_feed' => true }
      Social::FacebookDelta.new.perform(args)
    end
    assert_equal @method_call_count,0
  ensure
    Social::FacebookPage.any_instance.unstub(:valid_page?)
    sqs_instance.unstub :send_message
  end

  def test_add_feeds_to_sqs
    time = Time.now.utc
    @feeds = []
    2.times do
      feed = facebook_feed_hash(@fb_page.page_id, time , Faker::Lorem.characters(10))
      @feeds << feed
    end
    args = { 'page_id' => @fb_page.page_id, 'discard_feed' => false }
    @method_call_count = 0
    sqs_instance = AWS::SQS::Queue.new("{}")
    sqs_instance.stub :send_message, -> { true } do
      @method_call_count += 1;
      Social::DynamoHelper.stub :query, -> { @feeds } do
        @feeds.pop(1)
        Social::FacebookDelta.new.perform(args)
      end
    end
    assert_equal @feeds.size, @method_call_count
  ensure
    Social::DynamoHelper.unstub :query
    sqs_instance.unstub :send_message
  end

  def test_add_feeds_to_sqs_with_exception
    assert_nothing_raised do
      Social::DynamoHelper.stubs(:query).raises(Exception)
      args = { 'page_id' => @fb_page.page_id, 'discard_feed' => true }
      Social::FacebookDelta.new.perform(args)
    end
  ensure
   Social::DynamoHelper.unstub(:query)
  end
end
