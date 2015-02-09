require 'spec_helper'

RSpec.configure do |c|
  c.include GnipHelper
  c.include DynamoHelper
end

RSpec.describe Social::Gnip::TwitterFeed do

  self.use_transactional_fixtures = false

  before(:all) do
    Resque.inline = true
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      GnipRule::Client.any_instance.stubs(:add).returns(add_response)
    end
    @handle = create_test_twitter_handle(@account)
    @handle.update_attributes(:capture_dm_as_ticket => true)
    @default_stream = @handle.default_stream
    update_db(@default_stream) unless GNIP_ENABLED
    @default_stream.reload
    @ticket_rule = create_test_ticket_rule(@default_stream)
    @custom_stream = create_test_custom_twitter_stream(@handle)
    @data = @default_stream.data
    @rule = {:rule_value => @data[:rule_value], :rule_tag => @data[:rule_tag]}
    @account = @handle.account
    @account.make_current
    Resque.inline = false
  end

  before(:each) do
    @handle.reload
    @default_stream.reload
    unless GNIP_ENABLED
      Social::DynamoHelper.stubs(:insert).returns({})
      Social::DynamoHelper.stubs(:update).returns({})
    end
  end

  it "should create a ticket when a DM arrives" do  
    sample_dm = sample_twitter_dm("#{get_social_id}", Faker::Lorem.words(3), Time.zone.now.ago(3.days))
    @account.make_current
    # stub the api call
    twitter_dm = Twitter::DirectMessage.new(sample_dm)
    twitter_dm_array = [twitter_dm]
    Twitter::REST::Client.any_instance.stubs(:direct_messages).returns(twitter_dm_array)
    Social::Workers::Twitter::DirectMessage.perform({:account_id => @account.id})
    
    tweet = @account.tweets.find_by_tweet_id(sample_dm[:id])
    tweet.should_not be_nil
    tweet.is_ticket?.should be_truthy
    ticket_body = tweet.tweetable.ticket_body.description
    ticket_body.should eql(sample_dm[:text])
    # tweet.tweetable.destroy
  end

  it "should create a note when a DM arrives and if dm threaded time is greater than zero" do
    @handle.update_attributes(:dm_thread_time => 86400)

    # For creating ticket
    @account.make_current    
    user_id = "#{get_social_id}"
    user_name = Faker::Lorem.words(3)
    
    sample_dm = sample_twitter_dm(user_id, user_name, Time.zone.now.ago(3.hour))
    # stub the twitter api call
    twitter_dm = Twitter::DirectMessage.new(sample_dm)
    twitter_dm_array = [twitter_dm]
    Twitter::REST::Client.any_instance.stubs(:direct_messages).returns(twitter_dm_array)
    Social::Workers::Twitter::DirectMessage.perform({:account_id => @account.id})
    
    tweet = @account.tweets.find_by_tweet_id(sample_dm[:id])
    tweet.should_not be_nil
    tweet.is_ticket?.should be_truthy
    ticket = tweet.tweetable
    ticket_body = tweet.tweetable.ticket_body.description
    ticket_body.should eql(sample_dm[:text])
    
    # For creating notes
    sample_dm = sample_twitter_dm(user_id, user_name, Time.zone.now.ago(1.hour))
    # stub the twitter api call
    twitter_dm = Twitter::DirectMessage.new(sample_dm)
    twitter_dm_array = [twitter_dm]
    Twitter::REST::Client.any_instance.stubs(:direct_messages).returns(twitter_dm_array)
    Social::Workers::Twitter::DirectMessage.perform({:account_id => @account.id})

    tweet = @account.tweets.find_by_tweet_id(sample_dm[:id])
    tweet.should_not be_nil
    tweet.is_note?.should be_truthy
    ticket.notes.first.id.should eql tweet.tweetable.id
    note_body = tweet.tweetable.note_body.body
    note_body.should eql(sample_dm[:text])
    # ticket.destroy
  end
  
  it "should create a tickets and notes in the order of creation time when a DMs arrive" do
    user_id = "#{get_social_id}"
    @account.make_current
    user_name = Faker::Lorem.words(3)
    
    sample_dm1 = sample_twitter_dm(user_id, user_name, Time.zone.now.ago(3.hour))
    sample_dm2 = sample_twitter_dm(user_id, user_name, Time.zone.now.ago(2.hour))
    # stub the api call
    twitter_dm1 = Twitter::DirectMessage.new(sample_dm1)
    twitter_dm2 = Twitter::DirectMessage.new(sample_dm2)
    twitter_dm_array = [twitter_dm2, twitter_dm1]
    Twitter::REST::Client.any_instance.stubs(:direct_messages).returns(twitter_dm_array)
    
    Social::Workers::Twitter::DirectMessage.perform({:account_id => @account.id})
    
    tweet = @account.tweets.find_by_tweet_id(sample_dm1[:id])
    tweet.should_not be_nil
    tweet.is_ticket?.should be_truthy
    ticket = tweet.tweetable
    ticket_body = tweet.tweetable.ticket_body.description
    ticket_body.should eql(sample_dm1[:text])
    
    tweet = @account.tweets.find_by_tweet_id(sample_dm2[:id])
    tweet.should_not be_nil
    tweet.is_note?.should be_truthy
    note_body = tweet.tweetable.note_body.body
    note_body.should eql(sample_dm2[:text])
    # ticket.destroy
  end
  
  it "should create a ticket when a tweet arrives" do
    feed = sample_gnip_feed(@rule)
    tweet = send_tweet_and_wait(feed)

    tweet.should_not be_nil
    tweet.is_ticket?.should be_truthy
    tweet.stream_id.should_not be_nil

    tweet_body = feed["body"]
    body = tweet.tweetable.ticket_body.description
    tweet_body.should eql(body)
    dynamo_feed_for_tweet(@handle, feed, true) if GNIP_ENABLED
  end

  it "should create a note when a tweet is replied to" do
    #Send Tweet
    ticket_feed = sample_gnip_feed(@rule)
    ticket_tweet = send_tweet_and_wait(ticket_feed)

    ticket_tweet.should_not be_nil
    ticket_tweet.is_ticket?.should be_truthy
    ticket_tweet.stream_id.should_not be_nil
    dynamo_feed_for_tweet(@handle, ticket_feed, true) if GNIP_ENABLED

    #Send reply tweet
    ticket_tweet_id = ticket_feed["id"].split(":").last.to_i
    reply_feed = sample_gnip_feed(@rule, ticket_tweet_id)
    reply_tweet = send_tweet_and_wait(reply_feed)

    reply_tweet.should_not be_nil
    reply_tweet.is_note?.should be_truthy
    reply_tweet.stream_id.should_not be_nil

    reply_body = reply_feed["body"]
    body = reply_tweet.tweetable.note_body.body
    reply_body.should eql(body)
  end

  it "should convert a reply to a ticket if the 'replied-to' tweet doesnt come in the next 2 minutes" do
    #Send Tweet
    ticket_feed = sample_gnip_feed(@rule)
    
    #Send reply tweet
    ticket_tweet_id = ticket_feed["id"].split(":").last.to_i
    reply_feed = sample_gnip_feed(@rule, ticket_tweet_id)
    reply_tweet = send_tweet_and_wait(reply_feed)

    reply_tweet.should be_nil #Reply tweet will be converted to a ticket after 2 minutes

    reply_tweet_id = reply_feed["id"].split(":").last.to_i

    fd_counter = 120
    reply_tweet = wait_for_tweet(reply_tweet_id, reply_feed, fd_counter)

    reply_tweet.should_not be_nil
    reply_tweet.is_ticket?.should be_truthy
    reply_tweet.stream_id.should_not be_nil
    dynamo_feed_for_tweet(@handle, reply_feed, true) if GNIP_ENABLED

    reply_body = reply_feed["body"]
    body = reply_tweet.tweetable.ticket_body.description
    reply_body.should eql(body)
  end
  
  it "should convert the reply tweet to a note if the 'replied-to' tweet arrives within 2 minutes" do
    #Ticket feed
    ticket_feed = sample_gnip_feed(@rule)

    #Send reply tweet
    ticket_tweet_id = ticket_feed["id"].split(":").last.to_i
    reply_feed = sample_gnip_feed(@rule, ticket_tweet_id)
    reply_tweet = send_tweet_and_wait(reply_feed)

    reply_tweet.should be_nil #Reply tweet will be converted to a ticket after 3 minutes

    reply_tweet_id = reply_feed["id"].split(":").last.to_i

    fd_counter = 30

    fd_counter = fd_counter + 30
    reply_tweet = wait_for_tweet(reply_tweet_id, reply_feed, fd_counter)

    #Send 'replied-to' tweet
    tweet = send_tweet_and_wait(ticket_feed)

    reply_tweet_id = reply_feed["id"].split(":").last.to_i
    reply_tweet = wait_for_tweet(reply_tweet_id, reply_feed, fd_counter)

    #Reply tweet should be converted to a note
    reply_tweet.should_not be_nil
    reply_tweet.is_note?.should be_truthy
    reply_tweet.stream_id.should_not be_nil
    
    tweet.should_not be_nil
    tweet.is_ticket?.should be true
    tweet.stream_id.should_not be_nil
    
    
    reply_body = reply_feed["body"]
    body = reply_tweet.tweetable.note_body.body
    reply_body.should eql(body)
  end

  it "should not create a ticket if the feed does not have any matching rules" do
    feed = sample_gnip_feed()
    feed["gnip"]["matching_rules"] = []
    tweet = send_tweet_and_wait(feed)
    tweet.should be_nil
    dynamo_feed_for_tweet(@handle, feed, false) if GNIP_ENABLED
  end

  # it "should not convert a share/retweet to a ticket" do
  #   feed = sample_gnip_feed(@rule)
  #   feed["verb"] = "share"
  #   tweet = send_tweet_and_wait(feed)
  #   tweet.should be_nil
  #   dynamo_feed_for_tweet(@handle, feed, false)
  # end

  it "should not convert tweet with an invalid account_id in tag" do
    feed = sample_gnip_feed(@rule)
    rule = feed["gnip"]["matching_rules"].first
    rule["tag"] = "S#{@default_stream.id}_0"
    feed["gnip"]["matching_rules"] = [rule]

    tweet = send_tweet_and_wait(feed)
    tweet.should be_nil
    dynamo_feed_for_tweet(nil, feed, false, 0, @default_stream.id) if GNIP_ENABLED
  end

  it "should not convert tweet with an invalid stream_id in tag" do
    feed = sample_gnip_feed(@rule)
    rule = feed["gnip"]["matching_rules"].first
    rule["tag"] = "S0_#{@default_stream.account_id}"
    feed["gnip"]["matching_rules"] = [rule]

    tweet = send_tweet_and_wait(feed)
    tweet.should be_nil
    dynamo_feed_for_tweet(nil, feed, false, @handle.account_id, 0) if GNIP_ENABLED
  end

  it "should not convert tweet with an invalid twitter_handle_id in tag" do
    feed = sample_gnip_feed(@rule)
    rule = feed["gnip"]["matching_rules"].first
    rule["tag"] = "0_#{@handle.account_id}"
    feed["gnip"]["matching_rules"] = [rule]

    tweet = send_tweet_and_wait(feed)
    tweet.should be_nil
    dynamo_feed_for_tweet(nil, feed, false, @handle.account_id, 0) if GNIP_ENABLED
  end


  it "should create a rule value that matches twitter api when gnip subscription is false" do
    @custom_stream.includes = ["freshdesk", "zendesk", "\"freshdesk zendesk\"", "freshdesk zendesk"]
    @custom_stream.excludes = ["#freshdesk","#zendesk"]
    @custom_stream.filter[:exclude_twitter_handles] = ["desk"]
    @custom_stream.save

    twitter_rule_value = "((\"freshdesk zendesk\") OR freshdesk OR (freshdesk zendesk) OR zendesk -#freshdesk -#zendesk -from:desk) -rt"
    @custom_stream.data[:rule_value].should eql(twitter_rule_value)
  end
  
  it "should create new ticket when a DM arrives from same user and new handle and if it is within the dm threading interval" do
    # For creating ticket
    @account.make_current    
    user_id = "#{get_social_id}"
    user_name = Faker::Lorem.words(3)
    sample_dm = sample_twitter_dm(user_id, user_name, Time.zone.now.ago(3.hour))
    # stub the twitter api call
    twitter_dm = Twitter::DirectMessage.new(sample_dm)
    twitter_dm_array = [twitter_dm]
    Twitter::REST::Client.any_instance.stubs(:direct_messages).returns(twitter_dm_array)
    Social::Workers::Twitter::DirectMessage.perform({:account_id => @account.id})
    
    tweet = @account.tweets.find_by_tweet_id(sample_dm[:id])
    tweet.should_not be_nil
    tweet.is_ticket?.should be_truthy
    ticket = tweet.tweetable
    ticket_body = tweet.tweetable.ticket_body.description
    ticket_body.should eql(sample_dm[:text])
    ticket.destroy
    
    unless GNIP_ENABLED
      Gnip::RuleClient.any_instance.stubs(:delete).returns(delete_response)
      Gnip::RuleClient.any_instance.stubs(:add).returns(add_response) 
    end
    
    Resque.inline = true
    @handle.destroy
    
    @handle = create_test_twitter_handle(@account)
    @handle.update_attributes(:capture_dm_as_ticket => true, :capture_mention_as_ticket => true)
    @handle.update_ticket_rules(nil, ["#{@handle.formatted_handle}"])
    @default_stream = @handle.default_stream
    update_db(@default_stream) unless GNIP_ENABLED
    @data = @default_stream.data
    @rule = {:rule_value => @data[:rule_value], :rule_tag => @data[:rule_tag]}
    Resque.inline = false
      
    sample_dm = sample_twitter_dm(user_id, user_name, Time.zone.now.ago(1.hour))
    # stub the twitter api call
    twitter_dm = Twitter::DirectMessage.new(sample_dm)
    twitter_dm_array = [twitter_dm]
    Twitter::REST::Client.any_instance.stubs(:direct_messages).returns(twitter_dm_array)
    Social::Workers::Twitter::DirectMessage.perform({:account_id => @account.id})

    tweet = @account.tweets.find_by_tweet_id(sample_dm[:id])
    tweet.should_not be_nil
    tweet.is_ticket?.should be_truthy
    ticket = tweet.tweetable
    ticket_body = tweet.tweetable.ticket_body.description
    ticket_body.should eql(sample_dm[:text])
    ticket.destroy
  end


  after(:all) do
    #Destroy the twitter handle
    Resque.inline = true

    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      GnipRule::Client.any_instance.stubs(:delete).returns(delete_response)
    end

    Social::TwitterHandle.destroy_all
    Social::Stream.destroy_all

    # Social::Tweet.destroy_all
    Resque.inline = false
  end
end
