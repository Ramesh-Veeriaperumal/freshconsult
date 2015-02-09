require 'spec_helper'

include GnipHelper
include DynamoHelper
include Social::Twitter::Constants
include Social::Dynamo::Twitter
include Social::Util

describe Social::StreamsController do
  self.use_transactional_fixtures = false

  before(:all) do
    #handles
    Resque.inline = true
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([])
      GnipRule::Client.any_instance.stubs(:add).returns(add_response)
    end
    @first_handle = create_test_twitter_handle(@account)
    @first_default_stream = @first_handle.default_stream
    @first_data = @first_default_stream.data
    update_db(@first_default_stream) unless GNIP_ENABLED
    @first_rule = {:rule_value => @first_data[:rule_value], :rule_tag => @first_data[:rule_tag]}

    @sec_handle = create_test_twitter_handle(@account)
    @sec_default_stream = @sec_handle.default_stream
    @sec_data = @sec_default_stream.data
    update_db(@sec_default_stream) unless GNIP_ENABLED
    @sec_rule = {:rule_value => @sec_data[:rule_value], :rule_tag => @sec_data[:rule_tag]}
    Resque.inline = false
    AgentGroup.destroy_all
  end

  before(:each) do
    api_login
  end
  
  describe "interactions" do
    it "should show the entire current interaction on clicking on a tweet feed" do
      tweet_id1 = get_social_id
      tweet_id2 = tweet_id1 + 1
      tweet_id3 = tweet_id1 + 2
      tweet_id4 = tweet_id1 + 3

      tweet_id1, sample_gnip_feed1, sender1 = push_tweet_to_dynamo(tweet_id1, @first_rule, Time.now.utc.iso8601)
      tweet_id2, sample_gnip_feed2, sender2 = push_tweet_to_dynamo(tweet_id2, @first_rule,  Time.now.advance(:hours => +1).utc.iso8601, tweet_id1)
      tweet_id3, sample_gnip_feed3 = push_tweet_to_dynamo(tweet_id3, @first_rule,  Time.now.advance(:hours => +2).utc.iso8601, tweet_id2, sender1)
      tweet_id4, sample_gnip_feed4 = push_tweet_to_dynamo(tweet_id4, @first_rule,  Time.now.advance(:hours => +3).utc.iso8601, tweet_id3, sender2)

      sample_gnip_feed3.deep_symbolize_keys!

      get :interactions, {
                          :social_streams =>
                            {
                              :feed_id => "#{tweet_id3}",
                              :stream_id =>"#{@account.id}_#{@first_default_stream.id}",
                              :user_id => "#{sender1}",
                              :user_name => "GnipTestUser",
                              :user_screen_name => "GnipTestUser",
                              :user_image => "https://abs.twimg.com/sticky/default_profile_images/default_profile_5_normal.png",
                              :in_reply_to =>"",
                              :text => "#{sample_gnip_feed3[:body]}",
                              :parent_feed_id => "#{tweet_id1}",
                              :user_mentions => "TestingGnip",
                            },
                            :search_type => "streams",
                            :is_reply => "true",
                            :is_retweet => "false",
                            :format => "json"
                        }

      json_response.should include("current")
      json_response["current"][0].should include("feed_id", "parent_feed_id", "user_mentions", "posted_time", "body")
      json_response["current"][0]["user"].should include("name","screen_name","image")
      json_response["current"][0]["user"]["image"].should include("normal","bigger","mini")
    end
  end
  
end
