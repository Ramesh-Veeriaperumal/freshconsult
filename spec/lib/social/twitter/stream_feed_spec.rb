require 'spec_helper'
include GnipHelper
include DynamoHelper

describe Social::Twitter::Feed do

  self.use_transactional_fixtures = false

  before(:all) do
    Resque.inline = true
    @handle = create_test_twitter_handle()
    @stream = @handle.twitter_streams.first
    Resque.inline = false
  end

  before(:each) do
    @handle.reload
    @stream.reload
  end

  it "should create a ticket when a DM arrives" do
    account = @handle.account
    account.make_current
    
    sample_dm = sample_twitter_dm(Time.zone.now.ago(3.hours))
    # stub the api call
    twitter_dm = Twitter::DirectMessage.new(sample_dm)
    twitter_dm_array = [twitter_dm]
    Twitter::Client.any_instance.stubs(:direct_messages).returns(twitter_dm_array)
    Social::Twitter::Workers::DirectMessage.perform({:account_id => account.id})
    
    tweet = Social::Tweet.find_by_tweet_id(sample_dm[:id])
    tweet.should_not be_nil
    tweet.is_ticket?.should be_true
    ticket_body = tweet.tweetable.ticket_body.description
    ticket_body.should eql(sample_dm[:text])
  end
  
  it "should create a note when a DM arrives and if dm threaded time is greater than zero" do
    account = @handle.account
    account.make_current    
    
    # For creating ticket
    sample_dm = sample_twitter_dm(Time.zone.now.ago(2.hours))
    # stub the twitter api call
    twitter_dm = Twitter::DirectMessage.new(sample_dm)
    twitter_dm_array = [twitter_dm]
    Twitter::Client.any_instance.stubs(:direct_messages).returns(twitter_dm_array)
    Social::Twitter::Workers::DirectMessage.perform({:account_id => account.id})
    
    tweet = Social::Tweet.find_by_tweet_id(sample_dm[:id])
    tweet.should_not be_nil
    tweet.is_ticket?.should be_true
    ticket = tweet.tweetable
    ticket_body = tweet.tweetable.ticket_body.description
    ticket_body.should eql(sample_dm[:text])
    
    # For creating notes
    # update threaded time for twitter handle
    @handle.update_attributes(:dm_thread_time => 604800)
    
    sample_dm = sample_twitter_dm(Time.zone.now.ago(1.hour))
    # stub the twitter api call
    twitter_dm = Twitter::DirectMessage.new(sample_dm)
    twitter_dm_array = [twitter_dm]
    Twitter::Client.any_instance.stubs(:direct_messages).returns(twitter_dm_array)
    Social::Twitter::Workers::DirectMessage.perform({:account_id => account.id})

    tweet = Social::Tweet.find_by_tweet_id(sample_dm[:id])
    tweet.should_not be_nil
    tweet.is_note?.should be_true
    ticket.notes.first.id.should eql tweet.tweetable.id
    note_body = tweet.tweetable.note_body.body
    note_body.should eql(sample_dm[:text])
  end

  it "should create a ticket when a tweet arrives" do
    feed = sample_gnip_feed(@stream.data)
    tweet = send_tweet_and_wait(feed)

    tweet.should_not be_nil
    tweet.is_ticket?.should be_true
    tweet.stream_id.should_not be_nil

    tweet_body = feed["body"]
    body = tweet.tweetable.ticket_body.description
    tweet_body.should eql(body)
    dynamo_feed_for_tweet(@handle, feed, true)
  end

  it "should create a note when a tweet is replied to" do
    #Send Tweet
    ticket_feed = sample_gnip_feed(@stream.data)
    ticket_tweet = send_tweet_and_wait(ticket_feed)

    ticket_tweet.should_not be_nil
    ticket_tweet.is_ticket?.should be_true
    ticket_tweet.stream_id.should_not be_nil
    dynamo_feed_for_tweet(@handle, ticket_feed, true)

    #Send reply tweet
    ticket_tweet_id = ticket_feed["id"].split(":").last.to_i
    reply_feed = sample_gnip_feed(@stream.data, ticket_tweet_id)
    reply_tweet = send_tweet_and_wait(reply_feed)

    reply_tweet.should_not be_nil
    reply_tweet.is_note?.should be_true
    reply_tweet.stream_id.should_not be_nil

    reply_body = reply_feed["body"]
    body = reply_tweet.tweetable.note_body.body
    reply_body.should eql(body)
  end

  it "should convert a reply to a tweet if the 'replied-to' tweet doesnt come in the next 10 minutes" do
    #Send Tweet
    ticket_feed = sample_gnip_feed(@stream.data)
    sleep 1 #to ensure that the 'tweet' and 'reply' get different tweet_ids

    #Send reply tweet
    ticket_tweet_id = ticket_feed["id"].split(":").last.to_i
    reply_feed = sample_gnip_feed(@stream.data, ticket_tweet_id)
    reply_tweet = send_tweet_and_wait(reply_feed)

    reply_tweet.should be_nil #Reply tweet will be converted to a ticket after 10 minutes

    reply_tweet_id = reply_feed["id"].split(":").last.to_i
    reply_tweet = wait_for_tweet(reply_tweet_id, 660)

    reply_tweet.should_not be_nil
    reply_tweet.is_ticket?.should be_true
    reply_tweet.stream_id.should_not be_nil
    dynamo_feed_for_tweet(@handle, reply_feed, true)

    reply_body = reply_feed["body"]
    body = reply_tweet.tweetable.ticket_body.description
    reply_body.should eql(body)
  end

  it "should convert the reply tweet to a note if the 'replied-to' tweet arrives within 10 minutes" do
    #Send Tweet
    ticket_feed = sample_gnip_feed(@stream.data)

    sleep 1 #to ensure that the 'tweet' and 'reply' get different tweet_ids

    #Send reply tweet
    ticket_tweet_id = ticket_feed["id"].split(":").last.to_i
    reply_feed = sample_gnip_feed(@stream.data, ticket_tweet_id)
    reply_tweet = send_tweet_and_wait(reply_feed)

    reply_tweet.should be_nil #Reply tweet will be converted to a ticket after 10 minutes

    #Send 'replied-to' tweet
    ticket_tweet = send_tweet_and_wait(ticket_feed)
    ticket_tweet.should_not be_nil
    ticket_tweet.is_ticket?.should be_true
    ticket_tweet.stream_id.should_not be_nil
    dynamo_feed_for_tweet(@handle, ticket_feed, true)

    reply_tweet_id = reply_feed["id"].split(":").last.to_i
    reply_tweet = wait_for_tweet(reply_tweet_id, 600)

    #Reply tweet should be converted to a note
    reply_tweet.should_not be_nil
    reply_tweet.is_note?.should be_true
    reply_tweet.stream_id.should_not be_nil

    reply_body = reply_feed["body"]
    body = reply_tweet.tweetable.note_body.body
    reply_body.should eql(body)
  end

  it "should not create a ticket if the feed doesnot have any matching rules" do
    feed = sample_gnip_feed()
    feed["gnip"]["matching_rules"] = []
    tweet = send_tweet_and_wait(feed)
    tweet.should be_nil
    dynamo_feed_for_tweet(@handle, feed, false)
  end

  it "should not convert a share/retweet to a ticket" do
    feed = sample_gnip_feed(@stream.data)
    feed["verb"] = "share"
    tweet = send_tweet_and_wait(feed)
    tweet.should be_nil
    dynamo_feed_for_tweet(@handle, feed, false)
  end

  it "should convert tweets with @mentions to tickets" do
    feed = sample_gnip_feed(@stream.data)
    feed["body"] = "#{@handle.formatted_handle} @mention tweet"
    tweet = send_tweet_and_wait(feed)
    tweet.should_not be_nil
    tweet.stream_id.should_not be_nil
    dynamo_feed_for_tweet(@handle, feed, true)
  end

  it "should not convert tweets with keywords to tickets" do
    keys = @handle.search_keys - [@handle.formatted_handle]
    feed = sample_gnip_feed(@stream.data)
    feed["body"] = "#{keys.first} keywords tweet"
    tweet = send_tweet_and_wait(feed)
    tweet.should be_nil
    dynamo_feed_for_tweet(@handle, feed, true)
  end

  it "should not convert tweet with an invalid account_id in tag" do
    feed = sample_gnip_feed(@stream.data)
    rule = feed["gnip"]["matching_rules"].first
    rule["tag"] = "S#{@stream.id}_0"
    feed["gnip"]["matching_rules"] = [rule]

    tweet = send_tweet_and_wait(feed)
    tweet.should be_nil
    dynamo_feed_for_tweet(nil, feed, false, 0, @stream.id)
  end

  it "should not convert tweet with an invalid stream_id in tag" do
    feed = sample_gnip_feed(@stream.data)
    rule = feed["gnip"]["matching_rules"].first
    rule["tag"] = "S0_#{@handle.account_id}"
    feed["gnip"]["matching_rules"] = [rule]

    tweet = send_tweet_and_wait(feed)
    tweet.should be_nil
    dynamo_feed_for_tweet(nil, feed, false, @handle.account_id, 0)
  end

  it "should not convert tweet with an invalid twitter_handle_id in tag" do
    feed = sample_gnip_feed(@stream.data)
    rule = feed["gnip"]["matching_rules"].first
    rule["tag"] = "0_#{@handle.account_id}"
    feed["gnip"]["matching_rules"] = [rule]

    tweet = send_tweet_and_wait(feed)
    tweet.should be_nil
    dynamo_feed_for_tweet(nil, feed, false, @handle.account_id, 0)
  end


  after(:all) do
    #Destroy the twitter handle
    Resque.inline = true
    @handle.destroy
    Resque.inline = false
  end
end
