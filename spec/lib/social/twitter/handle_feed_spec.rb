require 'spec_helper'
include GnipHelper
include DynamoHelper

describe Social::Gnip::TwitterFeed do

  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    Resque.inline = true
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([])
      Gnip::RuleClient.any_instance.stubs(:add).returns(add_response)
    end
    @handle = create_test_twitter_handle(@account, true)
    update_handle_rule(@handle) unless GNIP_ENABLED
    Resque.inline = false
    @rule = {:rule_value => @handle.rule_value, :rule_tag => @handle.rule_tag}
  end

  before(:each) do
    @handle.reload unless @handle
  end

  it "should create a ticket when a DM arrives" do
    account = @handle.account
    account.make_current

    sample_dm = sample_twitter_dm("#{(Time.now.utc.to_f*100000).to_i}", Faker::Lorem.words(3), Time.zone.now.ago(7.days))
    # stub the api call
    twitter_dm = Twitter::DirectMessage.new(sample_dm)
    twitter_dm_array = [twitter_dm]
    Twitter::Client.any_instance.stubs(:direct_messages).returns(twitter_dm_array)
    Social::Workers::Twitter::DirectMessage.perform({:account_id => account.id})

    tweet = Social::Tweet.find_by_tweet_id(sample_dm[:id])
    tweet.should_not be_nil
    tweet.is_ticket?.should be_true
    ticket_body = tweet.tweetable.ticket_body.description
    ticket_body.should eql(sample_dm[:text])
  end

  it "should create a note when a DM arrives and if dm threaded time is greater less than one day" do
    @handle.update_attributes(:dm_thread_time => 86400)

    account = @handle.account
    account.make_current

    # For creating ticket
    user_id = "#{(Time.now.utc.to_f*100000).to_i}"
    user_name = Faker::Lorem.words(3)
    sample_dm = sample_twitter_dm(user_id, user_name, Time.zone.now.ago(3.hour))
    # stub the twitter api call
    twitter_dm = Twitter::DirectMessage.new(sample_dm)
    twitter_dm_array = [twitter_dm]
    Twitter::Client.any_instance.stubs(:direct_messages).returns(twitter_dm_array)
    Social::Workers::Twitter::DirectMessage.perform({:account_id => account.id})

    tweet = Social::Tweet.find_by_tweet_id(sample_dm[:id])
    tweet.should_not be_nil
    tweet.is_ticket?.should be_true
    ticket = tweet.tweetable
    ticket_body = tweet.tweetable.ticket_body.description
    ticket_body.should eql(sample_dm[:text])

    sample_dm = sample_twitter_dm(user_id, user_name, Time.zone.now.ago(1.hour))
    # stub the twitter api call
    twitter_dm = Twitter::DirectMessage.new(sample_dm)
    twitter_dm_array = [twitter_dm]
    Twitter::Client.any_instance.stubs(:direct_messages).returns(twitter_dm_array)
    Social::Workers::Twitter::DirectMessage.perform({:account_id => account.id})

    tweet = Social::Tweet.find_by_tweet_id(sample_dm[:id])
    tweet.should_not be_nil
    tweet.is_note?.should be_true
    ticket.notes.first.id.should eql tweet.tweetable.id
    note_body = tweet.tweetable.note_body.body
    note_body.should eql(sample_dm[:text])
  end


  it "should create a ticket when a tweet arrives" do
    feed = sample_gnip_feed(@rule)
    tweet = send_tweet_and_wait(feed)

    tweet.should_not be_nil
    tweet.is_ticket?.should be_true
    tweet.stream_id.should be_nil

    tweet_body = feed["body"]
    body = tweet.tweetable.ticket_body.description
    tweet_body.should eql(body)

    dynamo_feed_for_tweet(@handle, feed, false)
  end

  it "should create a note when a tweet is replied to" do
    #Send Tweet
    ticket_feed = sample_gnip_feed(@rule)
    ticket_tweet = send_tweet_and_wait(ticket_feed)

    ticket_tweet.should_not be_nil
    ticket_tweet.is_ticket?.should be_true
    ticket_tweet.stream_id.should be_nil
    dynamo_feed_for_tweet(@handle, ticket_feed, false)

    #Send reply tweet
    ticket_tweet_id = ticket_feed["id"].split(":").last.to_i
    reply_feed = sample_gnip_feed(@rule, ticket_tweet_id)
    reply_tweet = send_tweet_and_wait(reply_feed)

    reply_tweet.should_not be_nil
    reply_tweet.is_note?.should be_true
    reply_tweet.stream_id.should be_nil

    reply_body = reply_feed["body"]
    body = reply_tweet.tweetable.note_body.body
    reply_body.should eql(body)
  end

  it "should convert a reply to a tweet if the 'replied-to' tweet doesnt come in the next 10 minutes" do
    #Send Tweet
    ticket_feed = sample_gnip_feed(@rule)

    #Send reply tweet
    ticket_tweet_id = ticket_feed["id"].split(":").last.to_i
    reply_feed = sample_gnip_feed(@rule, ticket_tweet_id)
    reply_tweet = send_tweet_and_wait(reply_feed)
    reply_tweet.should be_nil #Reply tweet will be converted to a ticket after 10 minutes

    reply_tweet_id = reply_feed["id"].split(":").last.to_i

    fd_counter = 60
    while reply_tweet.nil? and fd_counter <= 240
      reply_tweet = send_tweet_and_wait(reply_feed, fd_counter)
      fd_counter = fd_counter + 60
    end

    reply_tweet.should_not be_nil
    reply_tweet.is_ticket?.should be_true

    reply_body = reply_feed["body"]
    body = reply_tweet.tweetable.ticket_body.description
    reply_body.should eql(body)
  end

  it "should convert the reply tweet to a note if the 'replied-to' tweet arrives within 10 minutes" do
    #Ticket feed
    ticket_feed = sample_gnip_feed(@rule)

    #Send reply tweet
    ticket_tweet_id = ticket_feed["id"].split(":").last.to_i
    reply_feed = sample_gnip_feed(@rule, ticket_tweet_id)
    reply_tweet = send_tweet_and_wait(reply_feed)
    reply_tweet.should be_nil #Reply tweet will be converted to a ticket after 10 minutes

    reply_tweet_id = reply_feed["id"].split(":").last.to_i

    fd_counter = 60
    while fd_counter < 240 and reply_tweet.nil?
      reply_tweet = send_tweet_and_wait(reply_feed, fd_counter)
      fd_counter = fd_counter + 60
    end
    reply_tweet.should be_nil

    #Send 'replied-to' tweet
    tweet = send_tweet_and_wait(ticket_feed)
    tweet.should_not be_nil
    tweet.is_ticket?.should be_true

    reply_tweet_id = reply_feed["id"].split(":").last.to_i
    reply_tweet = send_tweet_and_wait(reply_feed)

    #Reply tweet should be converted to a note
    reply_tweet.should_not be_nil
    reply_tweet.is_note?.should be_true

    reply_body = reply_feed["body"]
    body = reply_tweet.tweetable.note_body.body
    reply_body.should eql(body)
  end

  it "should not convert a share/retweet to a ticket" do
    feed = sample_gnip_feed(@rule)
    feed["verb"] = "share"
    tweet = send_tweet_and_wait(feed)
    tweet.should be_nil
    dynamo_feed_for_tweet(@handle, feed, false)
  end

  it "should convert tweets with @mentions to tickets" do
    feed = sample_gnip_feed(@rule)
    feed["body"] = "#{@handle.formatted_handle} @mention tweet"
    tweet = send_tweet_and_wait(feed)
    tweet.should_not be_nil
    tweet.stream_id.should be_nil
    dynamo_feed_for_tweet(@handle, feed, false)
  end

  it "should not convert tweet with an invalid account_id in tag" do
    feed = sample_gnip_feed(@rule)
    rule = feed["gnip"]["matching_rules"].first
    rule["tag"] = "#{@handle.id}_0"
    feed["gnip"]["matching_rules"] = [rule]

    tweet = send_tweet_and_wait(feed)
    tweet.should be_nil
    dynamo_feed_for_tweet(@handle, feed, false, 0, @handle.id)
  end

  it "should not convert tweet with an invalid twitter_handle_id in tag" do
    feed = sample_gnip_feed(@rule)
    rule = feed["gnip"]["matching_rules"].first
    rule["tag"] = "0_#{@handle.account_id}"
    feed["gnip"]["matching_rules"] = [rule]

    tweet = send_tweet_and_wait(feed)
    tweet.should be_nil
    dynamo_feed_for_tweet(@handle, feed, false, @handle.account_id, 0)
  end


  after(:all) do
    #Destroy the twitter handle
    Resque.inline = true
    Gnip::RuleClient.any_instance.stubs(:delete).returns(delete_response) unless GNIP_ENABLED
    @handle.destroy
    Resque.inline = false
  end
end
