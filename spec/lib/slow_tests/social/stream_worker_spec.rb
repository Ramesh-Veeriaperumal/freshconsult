require 'spec_helper'

RSpec.configure do |c|
  c.include GnipHelper
  c.include DynamoHelper
  c.include Social::Util
end

RSpec.describe "Social::Stream::Workers::Twitter" do 
  self.use_transactional_fixtures = false
  before(:all) do
    Resque.inline = true
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      Gnip::RuleClient.any_instance.stubs(:add).returns(add_response)
    end
    @handle = create_test_twitter_handle(@account)
    @default_stream = @handle.default_stream
    update_db(@default_stream) unless GNIP_ENABLED
    @default_stream.reload
    @ticket_rule = create_test_ticket_rule(@default_stream)
    @account = @handle.account
    @account.make_current
    Resque.inline = false
    unless GNIP_ENABLED
      Social::DynamoHelper.stubs(:insert).returns({})
      Social::DynamoHelper.stubs(:update).returns({})
    end
  end
  
  context "For a default stream when gnip flag is set to false" do
    it "must insert feeds into dynamo by making live search api call" do
      @default_stream.data.update(:gnip => false)
      @default_stream.save
      @ticket_rule.filter_data[:includes] = ["#{@handle.screen_name}"]
      @ticket_rule.save
      search_object = sample_search_results_object
      search_object.attrs[:statuses].first[:text] << " #{@handle.screen_name}"
      Twitter::REST::Client.any_instance.stubs(:search).returns(search_object)
      Social::Workers::Stream::Twitter.perform({:account_id => @account.id })
      hash_key = "#{@account.id}_#{@default_stream.id}"
      range_key = search_object.attrs[:statuses].first[:id_str]
      posted_time = search_object.attrs[:statuses].first[:created_at]
      dynamo_entry = dynamo_feeds_for_tweet("feeds", hash_key, range_key, posted_time)
  
      tweet = @account.tweets.find_by_tweet_id(range_key)
      tweet.should_not be_nil
      tweet.is_ticket?.should be_truthy
      
      if GNIP_ENABLED
        dynamo_entry.should_not be_nil
        dynamo_entry["feed_id"][:s].should eql("#{range_key}")
        dynamo_entry["fd_link"][:ss].first.should eql("#{helpdesk_ticket_link(tweet.tweetable)}")
      end
    end
  end
  
  after(:all) do
    Resque.inline = true
    @handle.destroy
    Resque.inline = false
  end
  
end
