require 'spec_helper'

RSpec.configure do |c|
  c.include GnipHelper
  c.include DynamoHelper
end

RSpec.describe Social::Twitter::Feed do

  self.use_transactional_fixtures = false

  before(:all) do
    Resque.inline = true
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      GnipRule::Client.any_instance.stubs(:add).returns(add_response)
    end
    @handle = create_test_twitter_handle(@account)
    @custom_stream = create_test_custom_twitter_stream(@handle)
    update_db(@handle.default_stream) unless GNIP_ENABLED
    Resque.inline = false
  end


  it "should not create a ticket if rule does not match when complex ticket rules are applied on a custom stream" do
    ticket_rule = create_test_ticket_rule(@custom_stream)
    ticket_rule.filter_data[:includes] = ["xyz"]
    ticket_rule.save

    @custom_stream.reload
    
    account = @handle.account
    account.make_current

    sample_feed = sample_twitter_feed.deep_symbolize_keys()
    sample_feed[:text] = "Don't be the average IT guy. Fight mediocrity. Help us save the hacker in you. Organized by @Freshdesk."
    sample_feed = Social::Twitter::Feed.new(sample_feed)

    sample_feed_array = [sample_feed]
    Social::CustomStreamTwitter.new.process_stream_feeds(sample_feed_array, @custom_stream, "#{get_social_id}")

    tweet = @account.tweets.find_by_tweet_id(sample_feed.feed_id)
    tweet.should be_nil
  end

  it "should create a ticket if rule matches when complex ticket rules is applied on a custom stream (using and)" do
    ticket_rule = create_test_ticket_rule(@custom_stream)
    ticket_rule.filter_data[:includes] = ["average guy"]
    ticket_rule.save

    @custom_stream.reload

    sample_feed = sample_twitter_feed.deep_symbolize_keys()
    sample_feed[:text] = "Don't be the average IT guy. Fight mediocrity. Help us save the hacker in you. Organized by @Freshdesk."
    sample_feed = Social::Twitter::Feed.new(sample_feed)


    sample_feed_array = [sample_feed]
    Social::CustomStreamTwitter.new.process_stream_feeds(sample_feed_array, @custom_stream, "#{get_social_id}")

    tweet = @account.tweets.find_by_tweet_id(sample_feed.feed_id)
    tweet.should_not be_nil
    tweet.is_ticket?.should be_truthy
    ticket_body = tweet.tweetable.ticket_body.description
    ticket_body.should eql(sample_feed.body)
    ticket = tweet.tweetable
    ticket.group_id.should eql(ticket_rule.action_data[:group_id])
    ticket.product_id.should eql(ticket_rule.action_data[:product_id])
  end

  it "should create a ticket if rule matches when complex ticket rules is applied on a custom stream(compound words - exact match)" do
    @custom_stream.ticket_rules.delete_all
    ticket_rule = create_test_ticket_rule(@custom_stream)
    ticket_rule.filter_data[:includes] = ["\"hacker in you\" average guy"]
    ticket_rule.save

    @custom_stream.reload

    sample_feed = sample_twitter_feed.deep_symbolize_keys()
    sample_feed[:text] = "Don't be the average IT guy. Fight mediocrity. Help us save the hacker in you. Organized by @Freshdesk."
    sample_feed = Social::Twitter::Feed.new(sample_feed)

    sample_feed_array = [sample_feed]
    Social::CustomStreamTwitter.new.process_stream_feeds(sample_feed_array, @custom_stream, "#{get_social_id}")

    tweet = @account.tweets.find_by_tweet_id(sample_feed.feed_id)
    tweet.should_not be_nil
    tweet.is_ticket?.should be_truthy
    ticket_body = tweet.tweetable.ticket_body.description
    ticket_body.should eql(sample_feed.body)
    ticket = tweet.tweetable
    ticket.group_id.should eql(ticket_rule.action_data[:group_id])
    ticket.product_id.should eql(ticket_rule.action_data[:product_id])
  end

  it "should create a ticket if rule matches when complex ticket rules is applied on a custom stream(single word)" do
    @custom_stream.ticket_rules.delete_all
    ticket_rule = create_test_ticket_rule(@custom_stream)
    ticket_rule.filter_data[:includes] = ["IT"]
    ticket_rule.save
    
    @custom_stream.reload
    
    sample_feed = sample_twitter_feed.deep_symbolize_keys()
    sample_feed[:text] = "Don't be the average IT guy. Fight mediocrity. Help us save the hacker in you. Organized by @Freshdesk."
    sample_feed = Social::Twitter::Feed.new(sample_feed)


    sample_feed_array = [sample_feed]
    Social::CustomStreamTwitter.new.process_stream_feeds(sample_feed_array, @custom_stream, "#{get_social_id}")

    tweet = @account.tweets.find_by_tweet_id(sample_feed.feed_id)
    tweet.should_not be_nil
    tweet.is_ticket?.should be_truthy
    ticket_body = tweet.tweetable.ticket_body.description
    ticket_body.should eql(sample_feed.body)
    ticket = tweet.tweetable
    ticket.group_id.should eql(ticket_rule.action_data[:group_id])
    ticket.product_id.should eql(ticket_rule.action_data[:product_id])
  end

  it "should create a rule value that matches twitter api when gnip subscription is false" do
    @custom_stream.includes = ["freshdesk", "zendesk", "freshdesk zendesk", "\"freshdesk zendesk\""]
    @custom_stream.excludes = ["#freshdesk","#zendesk"]
    @custom_stream.filter[:exclude_twitter_handles] = ["desk"]
    @custom_stream.save

    twitter_rule_value = "((\"freshdesk zendesk\") OR freshdesk OR (freshdesk zendesk) OR zendesk -#freshdesk -#zendesk -from:desk) -rt"
    @custom_stream.data[:rule_value].should eql(twitter_rule_value)
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
