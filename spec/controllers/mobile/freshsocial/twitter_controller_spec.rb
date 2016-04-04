require 'spec_helper'

include GnipHelper
include DynamoHelper
include Social::Twitter::Constants
#include Social::Dynamo::Twitter
include Social::Util
include Mobile::Constants

describe Social::TwitterController do
  self.use_transactional_fixtures = false

  before(:all) do
    Resque.inline = true
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      GnipRule::Client.any_instance.stubs(:add).returns(add_response)
    end
    @handle = create_test_twitter_handle(@account)
    @default_stream = @handle.default_stream
    @custom_stream = create_test_custom_twitter_stream(@handle)
    @data = @default_stream.data
    update_db(@default_stream) unless GNIP_ENABLED
    @rule = {:rule_value => @data[:rule_value], :rule_tag => @data[:rule_tag]}
    Resque.inline = false
  end
  
  before(:each) do
    @account.make_current
    unless GNIP_ENABLED
      Social::DynamoHelper.stubs(:insert).returns({})
      Social::DynamoHelper.stubs(:update).returns({})
    end
    api_login
  end
  
  describe "POST #fd_item" do
    it "should create a ticket and update dynamo for a tweet(in_reply_to.blank?) whose search type is saved" do
      tweet_id = (Time.now.utc.to_f*100000).to_i
      
      #Push a tweet into dynamo that is to be converted to ticket  
      unless GNIP_ENABLED 
        AWS::DynamoDB::ClientV2.any_instance.stubs(:query).returns(sample_dynamo_query_params)
        Social::DynamoHelper.stubs(:get_item).returns(sample_dynamo_get_item_params)
        Social::DynamoHelper.stubs(:batch_get).returns(sample_interactions_batch_get(tweet_id))
      end
      
      if GNIP_ENABLED
        tweet_id, sample_gnip_feed = push_tweet_to_dynamo(tweet_id)
        feed_entry, user_entry = dynamo_feed_for_tweet(@handle, sample_gnip_feed, true)
        feed_entry["fd_user"].should be_nil
        feed_entry["fd_link"].should be_nil
      else
        sample_gnip_feed = sample_gnip_feed(@rule, nil, Time.now.utc.iso8601)
        sample_gnip_feed["id"] = "tag:search.twitter.com,2005:#{tweet_id}"
      end
      
      #Pushed tweet should not be a ticket
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      tweet.should be_nil
      
      @stream_id = "#{@account.id}_#{@default_stream.id}"
      fd_item_params = sample_params_fd_item("#{tweet_id}", @stream_id, SEARCH_TYPE[:saved], "#{tweet_id}")
      fd_item_params[:item][:text] = sample_gnip_feed["body"]
      fd_item_params[:format] = "json"
      post :create_fd_item, fd_item_params
      json_response.should include("message","items","result")
      json_response["items"][0].should include("feed_id","link","user_in_db")
      tweet_id = fd_item_params[:item][:feed_id]
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      tweet.should_not be_nil
      tweet.is_ticket?.should be true
      
      if GNIP_ENABLED
        feed_entry, user_entry = dynamo_feed_for_tweet(@handle, sample_gnip_feed, true)
        feed_entry["fd_link"][:ss].first.should eql("#{helpdesk_ticket_link(tweet.tweetable)}")
        feed_entry["fd_user"][:ss].first.should eql("#{@account.all_users.find_by_twitter_id("GnipTestUser",:select => "id").id}")
      end  
    end

    it "should create a ticket for a tweet whose search type is custom" do
      @stream_id = "#{@account.id}_#{@custom_stream.id}"
      fd_item_params = sample_params_fd_item("#{(Time.now.utc.to_f*100000).to_i}", @stream_id, SEARCH_TYPE[:custom])
      fd_item_params[:format] = "json"
      post :create_fd_item, fd_item_params
      json_response.should include("message","items","result")
      json_response["items"][0].should include("feed_id","link","user_in_db")
      tweet_id = fd_item_params[:item][:feed_id]
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      tweet.should_not be_nil
      tweet.is_ticket?.should be true
      #Covering exception
      post :create_fd_item, fd_item_params 
      json_response.should include("message","items","result")  
      json_response["items"][0].should include("feed_id","link","user_in_db")
    end
    
    it "should create a note for a replied tweet whose search type is custom" do
      @stream_id = "#{@account.id}_#{@custom_stream.id}"
      fd_item_params = sample_params_fd_item("#{(Time.now.utc.to_f*100000).to_i}", @stream_id, SEARCH_TYPE[:custom])
      fd_item_params[:format] = "json"
      post :create_fd_item, fd_item_params
      json_response.should include("message","items","result")
      json_response["items"][0].should include("feed_id","link","user_in_db")
      tweet_id = fd_item_params[:item][:feed_id]
      
      #Check ticket
      tweet_id = fd_item_params[:item][:feed_id]
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      tweet.should_not be_nil
      tweet.is_ticket?.should be true
      ticket = tweet.tweetable
      
      @stream_id = "#{@account.id}_#{@custom_stream.id}"
      stream = Social::TwitterStream.find_by_id(@custom_stream.id)
      twitter_feed = sample_twitter_feed.deep_symbolize_keys
      reply_tweet_id = twitter_feed[:id]
      twitter_feed[:in_reply_to_status_id_str] = tweet_id
      twitter_feed = Social::Twitter::Feed.new(twitter_feed)
      Social::CustomStreamTwitter.new.process_stream_feeds([twitter_feed], stream, reply_tweet_id)
      
      tweet = @account.tweets.find_by_tweet_id(reply_tweet_id)
      tweet.should_not be_nil
      tweet.is_note?.should be true
      
      #Covering exception
      Social::CustomStreamTwitter.new.process_stream_feeds([twitter_feed], stream, reply_tweet_id)
    end
  end
  
  describe "POST #reply " do
    it "should reply to twitter and should push to dynamo if it is a custom stream and is a non ticket tweet" do   
      #Push a tweet into dynamo (parent tweet to reply to)
      tweet_id = (Time.now.utc.to_f*100000).to_i
      
      #Push a tweet into dynamo that is to be converted to ticket  
      unless GNIP_ENABLED 
        AWS::DynamoDB::ClientV2.any_instance.stubs(:query).returns(sample_dynamo_query_params)
        Social::DynamoHelper.stubs(:update).returns(dynamo_update_attributes(tweet_id))
        Social::DynamoHelper.stubs(:get_item).returns(sample_dynamo_get_item_params)
        Social::DynamoHelper.stubs(:batch_get).returns(sample_interactions_batch_get(tweet_id))
      end
      
      
      @stream_id = "#{@account.id}_#{@default_stream.id}"
      fd_item_params = sample_params_fd_item("#{tweet_id}", @stream_id, SEARCH_TYPE[:custom], "#{tweet_id}")
      
      #Stubing reply call
      twitter_object = sample_twitter_object(tweet_id)
      Twitter::REST::Client.any_instance.stubs(:update).returns(twitter_object)
      
      @stream_id = "#{@account.id}_#{@default_stream.id}"
      reply_params = sample_tweet_reply(@stream_id, tweet_id, SEARCH_TYPE[:custom])
      reply_params[:format] = "json"
      post :reply, reply_params
      json_response.should include("message","result")
    end
    
    
    it "should reply to twitter and should update dynamo if it is a saved stream and is a ticket tweet" do   
      #Push a tweet into dynamo (parent tweet to reply to)
      tweet_id = (Time.now.utc.to_f*100000).to_i
      
      #Push a tweet into dynamo that is to be converted to ticket  
      unless GNIP_ENABLED 
        AWS::DynamoDB::ClientV2.any_instance.stubs(:query).returns(sample_dynamo_query_params)
        Social::DynamoHelper.stubs(:update).returns(dynamo_update_attributes(tweet_id))
        Social::DynamoHelper.stubs(:get_item).returns(sample_dynamo_get_item_params)
        Social::DynamoHelper.stubs(:batch_get).returns(sample_interactions_batch_get(tweet_id))
      end
      
      
      if GNIP_ENABLED
        tweet_id, sample_gnip_feed = push_tweet_to_dynamo(tweet_id)
        feed_entry, user_entry = dynamo_feed_for_tweet(@handle, sample_gnip_feed, true)
        feed_entry["fd_user"].should be_nil
        feed_entry["fd_link"].should be_nil
        feed_entry["in_conversation"][:n].should eql("0")
        feed_entry["is_replied"][:n].should eql("0")
      end
      
      @stream_id = "#{@account.id}_#{@default_stream.id}"
      fd_item_params = sample_params_fd_item("#{tweet_id}", @stream_id, SEARCH_TYPE[:saved], "#{tweet_id}")
      fd_item_params[:format] = "json"
      post :create_fd_item, fd_item_params
      tweet_id = fd_item_params[:item][:feed_id]
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      tweet.should_not be_nil
      tweet.is_ticket?.should be true
      ticket = tweet.tweetable
      
      if GNIP_ENABLED
        feed_entry, user_entry = dynamo_feed_for_tweet(@handle, sample_gnip_feed, true)
        feed_entry["fd_link"][:ss].first.should eql("#{helpdesk_ticket_link(tweet.tweetable)}")
        feed_entry["fd_user"][:ss].first.should eql("#{@account.all_users.find_by_twitter_id("GnipTestUser",:select => "id").id}")
      end
      
      #Stubing reply call
      twitter_object = sample_twitter_object(tweet_id)
      Twitter::REST::Client.any_instance.stubs(:update).returns(twitter_object)
      
      @stream_id = "#{@account.id}_#{@default_stream.id}"
      reply_params = sample_tweet_reply(@stream_id, tweet_id, SEARCH_TYPE[:saved])
      post :reply, reply_params
      json_response.should include("message","result")
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      tweet.should_not be_nil
      
      if GNIP_ENABLED
        feed_entry, user_entry = dynamo_feed_for_tweet(@handle, sample_gnip_feed, true)
        feed_entry["in_conversation"][:n].should eql("1")
        feed_entry["is_replied"][:n].should eql("1")
      end
    end 
  end

  it "should return the live search results and five recent searches by live search stored in redis" do
    $redis_others.del("STREAM_RECENT_SEARCHES:#{@account.id}:#{@agent.id}")
    Twitter::REST::Client.any_instance.stubs(:search).returns(sample_search_results_object)

    @account.twitter_handles.update_all(:state => Social::TwitterHandle::TWITTER_STATE_KEYS_BY_TOKEN[:active]) # to avoid re-auth errors from cropping up
    @account.make_current
    
    5.times do |n|
      search_hash  = {
        "query"        => ["#{n}"],
        "handles"      => [],
        "keywords"     => [],
        "query_string" => ""
      }
      @agent.agent.add_social_search(search_hash)
    end

    get :twitter_search, {
                            :search => {
                              :q => ["hello world"], 
                              :type => "custom_search", 
                              :next_results => "", 
                              :refresh_url => ""
                            },
                            :format => "json"
                          }
    json_response.should include("sorted_feeds", "max_id", "since_id", "reply_privilege")
    # recent_search = response.template_objects["recent_search"]
    # recent_search.first["query"].should eql(["hello world"])
    # recent_search.second["query"].should eql(["4"])
    # recent_search.third["query"].should eql(["3"])
    # recent_search.fourth["query"].should eql(["2"])
    # recent_search.fifth["query"].should eql(["1"])    
  end

  it "should return older results on  live search" do
      Twitter::REST::Client.any_instance.stubs(:search).returns(sample_search_results_object)
      get :show_old, {
                              :search => {
                                :q => ["show old"], 
                                :type => "custom_search", 
                                :next_results => "", 
                                :refresh_url => ""
                              },
                              :format => "json"
                            }
                            
      json_response.should include("sorted_feeds", "max_id", "since_id", "reply_privilege")
  end
  
  it "should newer results on  live search" do
    Twitter::REST::Client.any_instance.stubs(:search).returns(sample_search_results_object)
    get :fetch_new, {
                            :search => {
                              :q => ["new results"], 
                              :type => "custom_search", 
                              :next_results => "", 
                              :refresh_url => ""
                            },
                            :format => "json"
                          }
    json_response.should include("sorted_feeds", "max_id", "since_id", "reply_privilege")
  end  
    
  it "should post a tweet to twitter" do
    Twitter::REST::Client.any_instance.stubs(:update).returns(sample_twitter_tweet_object)
    post :post_tweet, {
                        :tweet => 
                          {
                            :body => "Text"
                          },
                        :twitter_handle_id => "#{@handle.id}",
                        :format => "json"
                      }
    json_response.should include("message","result")
  end

  it "should favorite the tweet on clicking the favorite icon" do
    tweet_id = (Time.now.utc.to_f*100000).to_i
      
    #Push a tweet into dynamo that is to be converted to ticket  
    unless GNIP_ENABLED 
      AWS::DynamoDB::ClientV2.any_instance.stubs(:query).returns(sample_dynamo_query_params)
      Social::DynamoHelper.stubs(:get_item).returns(sample_dynamo_get_item_params)
      Social::DynamoHelper.stubs(:batch_get).returns(sample_interactions_batch_get(tweet_id))
    end
    

    if GNIP_ENABLED
      tweet_id, sample_gnip_feed = push_tweet_to_dynamo(tweet_id)
      feed_entry, user_entry = dynamo_feed_for_tweet(@handle, sample_gnip_feed, true)
    else
      sample_gnip_feed = sample_gnip_feed(@rule, nil, Time.now.utc.iso8601)
      sample_gnip_feed["id"] = "tag:search.twitter.com,2005:#{@tweet_id}"
    end
    
    #Pushed tweet should not be a ticket
    tweet = @account.tweets.find_by_tweet_id(tweet_id)
    tweet.should be_nil
        
    feed_id = tweet_id
    Twitter::REST::Client.any_instance.stubs(:favorite).returns([feed_id])
    post :favorite, {
       :item => {
        :stream_id => "#{@account.id}_#{@default_stream.id}",
        :feed_id => feed_id
       },
       :format => "json"
    }
    
    if GNIP_ENABLED
      feed_entry, user_entry = dynamo_feed_for_tweet(@handle, sample_gnip_feed, true)
      feed_entry["favorite"][:n].first.should eql("1")
    end  
    
    json_response.should include("message","result")
    json_response["message"].should be_eql(MOBILE_TWITTER_RESPONSE_CODES[:favorite_success])
    json_response["result"].should be true
  end
  
  it "should unfavorite the tweet on clicking the unfavorite icon" do
    tweet_id = (Time.now.utc.to_f*100000).to_i
      
    #Push a tweet into dynamo that is to be converted to ticket  
    unless GNIP_ENABLED 
      AWS::DynamoDB::ClientV2.any_instance.stubs(:query).returns(sample_dynamo_query_params)
      Social::DynamoHelper.stubs(:get_item).returns(sample_dynamo_get_item_params)
      Social::DynamoHelper.stubs(:batch_get).returns(sample_interactions_batch_get(tweet_id))
    end
    

    if GNIP_ENABLED
      tweet_id, sample_gnip_feed = push_tweet_to_dynamo(tweet_id)
      feed_entry, user_entry = dynamo_feed_for_tweet(@handle, sample_gnip_feed, true)
    else
      sample_gnip_feed = sample_gnip_feed(@rule, nil, Time.now.utc.iso8601)
      sample_gnip_feed["id"] = "tag:search.twitter.com,2005:#{@tweet_id}"
    end
    
    #Pushed tweet should not be a ticket
    tweet = @account.tweets.find_by_tweet_id(tweet_id)
    tweet.should be_nil
        
    feed_id = tweet_id
    Twitter::REST::Client.any_instance.stubs(:favorite).returns([feed_id])
    post :favorite, {
       :item => {
        :stream_id => "#{@account.id}_#{@default_stream.id}",
        :feed_id => feed_id
       },
       :format => "json"
    }
    
    if GNIP_ENABLED
      feed_entry, user_entry = dynamo_feed_for_tweet(@handle, sample_gnip_feed, true)
      feed_entry["favorite"][:n].first.should eql("1")
    end  
    
    
    feed_id = tweet_id
    Twitter::REST::Client.any_instance.stubs(:unfavorite).returns([feed_id])
    post :unfavorite, {
       :item => {
        :stream_id => "#{@account.id}_#{@default_stream.id}",
        :feed_id => feed_id
       },
       :format => "json"
    }

    json_response.should include("message","result")
    json_response["message"].should be_eql(MOBILE_TWITTER_RESPONSE_CODES[:unfavorite_success])
    json_response["result"].should be true

    if GNIP_ENABLED
      feed_entry, user_entry = dynamo_feed_for_tweet(@handle, sample_gnip_feed, true)
      feed_entry["favorite"][:n].first.should eql("0")
    end  
    
  end

  after(:all) do
    #Destroy the twitter handle
    Resque.inline = true
    unless GNIP_ENABLED
      GnipRule::Client.any_instance.stubs(:list).returns([]) 
      GnipRule::Client.any_instance.stubs(:delete).returns(delete_response) 
    end
    # @handle.destroy
    # Social::Stream.destroy_all
    # Social::Tweet.destroy_all
    Resque.inline = false
  end
  
end
