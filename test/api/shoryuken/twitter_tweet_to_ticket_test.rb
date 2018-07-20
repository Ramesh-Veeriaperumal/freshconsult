require_relative '../unit_test_helper'
require_relative '../../test_transactions_fixtures_helper'
require Rails.root.join('test', 'core', 'helpers', 'twitter_test_helper.rb')

class TwitterTweetToTicketTest < ActionView::TestCase
  include TwitterTestHelper

  def teardown
    cleanup_twitter_handles(@account)
  end

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    handle = create_test_twitter_handle(@account)
    @stream = handle.default_stream
  end

  def test_twitter_tweets_convert_as_ticket
    tweet_feed = sample_gnip_feed(@account, @stream)
    sqs_msg = Hashit.new(body: tweet_feed.to_json)
    Ryuken::TwitterTweetToTicket.new.perform(sqs_msg, nil)
    ticket = @account.tickets.last
    assert_equal ticket.description, tweet_feed['body']
  end

  def test_twitter_tweets_convert_to_note
    tweet_feed = sample_gnip_feed(@account, @stream)
    sqs_msg = Hashit.new(body: tweet_feed.to_json)
    response = Ryuken::TwitterTweetToTicket.new.perform(sqs_msg, nil)
    ticket = @account.tickets.last
    tweet_id = ticket.tweet.tweet_id
    reply_feed = sample_gnip_feed(@account, @stream, tweet_id)
    sqs_msg = Hashit.new(body: reply_feed.to_json)
    Ryuken::TwitterTweetToTicket.new.perform(sqs_msg, nil)
    note = ticket.notes.last
    assert_equal note.note_body.body, reply_feed['body']
  end

  def test_twitter_tweets_with_media_content
    media_url = 'https://t.co/TestingGnip'
    tweet_feed = sample_gnip_feed(@account, @stream, false, media_url)
    sqs_msg = Hashit.new(body: tweet_feed.to_json)
    attachment = stub_twitter_attachments_hash(media_url)
    Social::Gnip::TwitterFeed.any_instance.stubs(:construct_media_url_hash_tweets).returns(attachment)
    Ryuken::TwitterTweetToTicket.new.perform(sqs_msg, nil)
    image_content = '<img src="https://attachmenttestlink.com" data-test-src="https://pbs.twimg.com/media/HsEgj7f3jhgWDR.jpg"'
    assert_includes Helpdesk::Ticket.last.description_html, image_content
  end
end
