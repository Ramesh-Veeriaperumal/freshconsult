require 'spec_helper'

RSpec.configure do |c|
  c.include GnipHelper
  c.include DynamoHelper
  c.include Social::Twitter::Constants
  c.include Social::Dynamo::Twitter
  c.include Social::Util
end

RSpec.describe Social::TwitterController do
  setup :activate_authlogic
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
    log_in(@agent)
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
      post :create_fd_item, fd_item_params
      
      tweet_id = fd_item_params[:item][:feed_id]
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      tweet.should_not be_nil
      tweet.is_ticket?.should be_truthy
      
      if GNIP_ENABLED
        feed_entry, user_entry = dynamo_feed_for_tweet(@handle, sample_gnip_feed, true)
        feed_entry["fd_link"][:ss].first.should eql("#{helpdesk_ticket_link(tweet.tweetable)}")
        feed_entry["fd_user"][:ss].first.should eql("#{@account.all_users.find_by_twitter_id("GnipTestUser",:select => "id").id}")
      end  
    end

    it "should create a ticket for a tweet whose search type is custom" do
      @stream_id = "#{@account.id}_#{@custom_stream.id}"
      fd_item_params = sample_params_fd_item("#{(Time.now.utc.to_f*100000).to_i}", @stream_id, SEARCH_TYPE[:custom])
      post :create_fd_item, fd_item_params
      tweet_id = fd_item_params[:item][:feed_id]
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      tweet.should_not be_nil
      tweet.is_ticket?.should be_truthy
      
      #Covering exception
      post :create_fd_item, fd_item_params   
    end
    
    it "should create a note for a replied tweet whose search type is custom" do
      @stream_id = "#{@account.id}_#{@custom_stream.id}"
      fd_item_params = sample_params_fd_item("#{(Time.now.utc.to_f*100000).to_i}", @stream_id, SEARCH_TYPE[:custom])
      post :create_fd_item, fd_item_params
      tweet_id = fd_item_params[:item][:feed_id]
      
      #Check ticket
      tweet_id = fd_item_params[:item][:feed_id]
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      tweet.should_not be_nil
      tweet.is_ticket?.should be_truthy
      ticket = tweet.tweetable
      
      @stream_id = "#{@account.id}_#{@custom_stream.id}"
      stream = Social::TwitterStream.find_by_id(@custom_stream.id)
      twitter_feed = sample_twitter_feed.deep_symbolize_keys
      reply_tweet_id = twitter_feed[:id]
      twitter_feed[:in_reply_to_status_id_str] = tweet_id
      twitter_feed = Social::Twitter::Feed.new(twitter_feed)
      Social::Workers::Stream::Twitter.process_stream_feeds([twitter_feed], stream, reply_tweet_id)
      
      tweet = @account.tweets.find_by_tweet_id(reply_tweet_id)
      tweet.should_not be_nil
      tweet.is_note?.should be_truthy
      
      #Covering exception
      Social::Workers::Stream::Twitter.process_stream_feeds([twitter_feed], stream, reply_tweet_id)
      tweet.is_note?.should be_truthy
    end
  end
  
  describe "POST #reply " do
    it "should reply to twitter and should push to dynamo if it is a custom stream and is a ticket tweet" do   
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
      post :create_fd_item, fd_item_params
      tweet_id = fd_item_params[:item][:feed_id]
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      tweet.should_not be_nil
      tweet.is_ticket?.should be_truthy
      ticket = tweet.tweetable
      
      #Stubing reply call
      twitter_object = sample_twitter_object(tweet_id)
      Twitter::REST::Client.any_instance.stubs(:update).returns(twitter_object)
      
      @stream_id = "#{@account.id}_#{@default_stream.id}"
      reply_params = sample_tweet_reply(@stream_id, tweet_id, SEARCH_TYPE[:saved])
      post :reply, reply_params
      
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      tweet.should_not be_nil
    end
    
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
      post :reply, reply_params
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
      post :create_fd_item, fd_item_params
      tweet_id = fd_item_params[:item][:feed_id]
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      tweet.should_not be_nil
      tweet.is_ticket?.should be_truthy
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
      
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      tweet.should_not be_nil
      
      if GNIP_ENABLED
        feed_entry, user_entry = dynamo_feed_for_tweet(@handle, sample_gnip_feed, true)
        feed_entry["in_conversation"][:n].should eql("1")
        feed_entry["is_replied"][:n].should eql("1")
      end
    end

    it "should reply to twitter if it is a saved stream and is a non ticket tweet should update dynamo" do   
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
        feed_entry["in_conversation"][:n].should eql("0")
        feed_entry["is_replied"][:n].should eql("0")
      end
      
      #Stubing reply call
      twitter_object = sample_twitter_object(tweet_id)
      Twitter::REST::Client.any_instance.stubs(:update).returns(twitter_object)
      
      @stream_id = "#{@account.id}_#{@default_stream.id}"
      reply_params = sample_tweet_reply(@stream_id, tweet_id, SEARCH_TYPE[:saved])
      post :reply, reply_params
      
      #Check update of parent feed
      if GNIP_ENABLED
        feed_entry, user_entry = dynamo_feed_for_tweet(@handle, sample_gnip_feed, true)
        feed_entry["in_conversation"][:n].should eql("1")
        feed_entry["is_replied"][:n].should eql("1")
      end
      
      hash_key = "#{@account.id}_#{@default_stream.id}"
      reply_tweet_id = "#{twitter_object.attrs[:id]}"
      reply_user_id = "#{twitter_object.attrs[:user][:id_str]}"
     
      if GNIP_ENABLED
         reply_feed_entry = dynamo_feeds_for_tweet("feeds", hash_key, reply_tweet_id, twitter_object.attrs[:created_at])
         reply_user_entry = dynamo_feeds_for_tweet("interactions", hash_key, "user:#{reply_user_id}", twitter_object.attrs[:created_at])
          
         reply_feed_entry["in_conversation"][:n].should eql("1")
         reply_feed_entry["is_replied"][:n].should eql("0")
         reply_feed_entry["parent_feed_id"][:ss].first.should eql("#{tweet_id}")
      end
    end  
    
    it "should reply to twitter if it is a live stream" do   
      #Stubing reply call
      twitter_object = sample_twitter_object((Time.now.utc.to_f*100000).to_i)
      Twitter::REST::Client.any_instance.stubs(:update).returns(twitter_object)
      
      @stream_id = "#{@account.id}_#{@default_stream.id}"
      reply_params = sample_tweet_reply(@stream_id, (Time.now.utc.to_f*100000).to_i, SEARCH_TYPE[:live])
      post :reply, reply_params
    end
    
    it "should reply to twitter if it is a saved stream and is a non ticket tweet should update dynamo" do   
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
        feed_entry["in_conversation"][:n].should eql("0")
        feed_entry["is_replied"][:n].should eql("0")
      end
      
      #Stubing reply call
      twitter_object = sample_twitter_object(tweet_id)
      Twitter::REST::Client.any_instance.stubs(:update).returns(twitter_object)
      
      @stream_id = "#{@account.id}_#{@default_stream.id}"
      reply_params = sample_tweet_reply(@stream_id, tweet_id, SEARCH_TYPE[:saved])
      post :reply, reply_params
      
      
      #Check update of parent feed
      if GNIP_ENABLED
        feed_entry, user_entry = dynamo_feed_for_tweet(@handle, sample_gnip_feed, true)
        feed_entry["in_conversation"][:n].should eql("1")
        feed_entry["is_replied"][:n].should eql("1")
        
        hash_key = "#{@account.id}_#{@default_stream.id}"
        reply_tweet_id = "#{twitter_object.attrs[:id]}"
        reply_user_id = "#{twitter_object.attrs[:user][:id_str]}"
        reply_feed_entry = dynamo_feeds_for_tweet("feeds", hash_key, reply_tweet_id, twitter_object.attrs[:created_at])
        reply_user_entry = dynamo_feeds_for_tweet("interactions", hash_key, "user:#{reply_user_id}", twitter_object.attrs[:created_at])
        
        reply_feed_entry["in_conversation"][:n].should eql("1")
        reply_feed_entry["is_replied"][:n].should eql("0")
        reply_feed_entry["parent_feed_id"][:ss].first.should eql("#{tweet_id}")
      end
    end  
    
    it "should reply to twitter and should update dynamo if it is a saved stream and is a ticket tweet" do   
      # Push a tweet into dynamo (parent tweet to reply to)
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
        feed_entry["in_conversation"][:n].should eql("0")
        feed_entry["is_replied"][:n].should eql("0")
      end
      
      #Create ticket
      @stream_id = "#{@account.id}_#{@default_stream.id}"
      fd_item_params = sample_params_fd_item("#{tweet_id}", @stream_id, SEARCH_TYPE[:saved], "#{tweet_id}")
      
      post :create_fd_item, fd_item_params
      tweet_id = fd_item_params[:item][:feed_id]
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      tweet.should_not be_nil
      tweet.is_ticket?.should be_truthy
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
      
      tweet = @account.tweets.find_by_tweet_id(tweet_id)
      tweet.should_not be_nil
     
      hash_key = "#{@account.id}_#{@default_stream.id}"
      reply_tweet_id = "#{twitter_object.attrs[:id]}"
      reply_user_id = "#{twitter_object.attrs[:user][:id_str]}"
      
      if GNIP_ENABLED
        reply_feed_entry = dynamo_feeds_for_tweet("feeds", hash_key, reply_tweet_id, twitter_object.attrs[:created_at])
        reply_user_entry = dynamo_feeds_for_tweet("interactions", hash_key, "user:#{reply_user_id}", twitter_object.attrs[:created_at])
        
        reply_feed_entry["in_conversation"][:n].should eql("1")
        reply_feed_entry["is_replied"][:n].should eql("0")
        reply_feed_entry["parent_feed_id"][:ss].first.should eql("#{tweet_id}")
      end
    end   
  end
  
  it "should show all the user interactions and tickets of the user accross streams on click of user profile" do
    if GNIP_ENABLED 
      Resque.inline = true   
      sec_handle = create_test_twitter_handle(@account)
      Resque.inline = false
      
      sec_default_stream = sec_handle.default_stream
      data = sec_default_stream.data
      sec_rule = {:rule_value => @data[:rule_value], :rule_tag => @data[:rule_tag]}
      
      tweet_id1, sample_gnip_feed1, sender1 = push_tweet_to_dynamo(@rule, Time.now.utc.iso8601)
      tweet_id2, sample_gnip_feed2 = push_tweet_to_dynamo(sec_rule,  Time.now.advance(:hours => +1).utc.iso8601, tweet_id1, sender1)
     
      sample_gnip_feed2.deep_symbolize_keys!
      
      Twitter::REST::Client.any_instance.stubs(:users).returns([sample_twitter_user(sender1)])
      
      get :user_info,  {
                          :user => 
                              {
                                :screen_name => "GnipTesting",
                                :name => "GnipTesting", 
                                :id => "#{sender1}", 
                                :klout_score => "", 
                                :normal_img_url => "https://abs.twimg.com/sticky/default_profile_images/default_profile_5_normal.png"
                              }
                      }
                  
                  
      user_interactions = assigns[:interactions][:others]
      user_interactions.length.should eql(2)
      user_interactions.map{|t| t.feed_id}.should include("#{tweet_id1}", "#{tweet_id2}")
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
                              :type => "live_search", 
                              :next_results => "", 
                              :refresh_url => ""
                            }
                          }
    Rails.logger.info response
    Rails.logger.info "%"*100
    Rails.logger.info assigns[:recent_search].inspect  
    recent_search = assigns[:recent_search]
    recent_search.first["query"].should eql(["hello world"])
    recent_search.second["query"].should eql(["4"])
    recent_search.third["query"].should eql(["3"])
    recent_search.fourth["query"].should eql(["2"])
    recent_search.fifth["query"].should eql(["1"])     
  end

  it "should return older results on  live search" do
      Twitter::REST::Client.any_instance.stubs(:search).returns(sample_search_results_object)
      request.env["HTTP_ACCEPT"] = "application/javascript"
      get :show_old, {
                              :search => {
                                :q => ["show old"], 
                                :type => "live_search", 
                                :next_results => "", 
                                :refresh_url => ""
                              }
                            }
                            
      response.should render_template("social/twitter/show_old")
  end
  
  it "should newer results on  live search" do
    Twitter::REST::Client.any_instance.stubs(:search).returns(sample_search_results_object)
    request.env["HTTP_ACCEPT"] = "application/javascript"
    get :fetch_new, {
                            :search => {
                              :q => ["new results"], 
                              :type => "live_search", 
                              :next_results => "", 
                              :refresh_url => ""
                            }
                          }
    response.should render_template("social/twitter/fetch_new")
  end  
  
  it "should fetch retweet when retweeting a particular tweet" do
    Twitter::REST::Client.any_instance.stubs(:retweet).returns("")
     request.env["HTTP_ACCEPT"] = "application/javascript"
      get :retweet, {
          :tweet => {
            :feed_id => "#{(Time.now.utc.to_f*100000).to_i}"
          }
        }
        
    response.should render_template("social/twitter/retweet")
  end
  
  it "should fetch retweets from twitter when clicking on a particular tweet" do
    Twitter::REST::Client.any_instance.stubs(:status).returns(sample_twitter_tweet_object)
    Twitter::REST::Client.any_instance.stubs(:retweets).returns([sample_twitter_tweet_object])
    request.env["HTTP_ACCEPT"] = "application/javascript"
      get :retweets, {
          :retweeted_id => "472324358761750530"
        }
    response.should render_template("social/twitter/retweets")
  end
  
  it "should post a tweet to twitter" do
    Twitter::REST::Client.any_instance.stubs(:update).returns(sample_twitter_tweet_object)
    post :post_tweet, {
                        :tweet => 
                          {
                            :body => "Text"
                          },
                        :twitter_handle_id => "#{@handle.id}"
                      }
  end
  
  it "should retrieve all user info on clicking on the user link" do
    Twitter::REST::Client.any_instance.stubs(:users).returns([sample_twitter_user((Time.now.utc.to_f*100000).to_i)])
    request.env["HTTP_ACCEPT"] = "application/javascript"
    get :user_info, {
        :user => {
          :name => "GnipTesting", 
          :screen_name => "@GnipTesting",
          :normal_img_url => "https://si0.twimg.com/profile_images/2816192909/db88b820451fa8498e8f3cf406675e13_normal.png"
        }
    }
    response.should render_template("social/twitter/user_info")
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
    request.env["HTTP_ACCEPT"] = "application/javascript"
    post :favorite, {
       :item => {
        :stream_id => "#{@account.id}_#{@default_stream.id}",
        :feed_id => feed_id
       },
       :search_type => SEARCH_TYPE[:saved]
    }
    
    if GNIP_ENABLED
      feed_entry, user_entry = dynamo_feed_for_tweet(@handle, sample_gnip_feed, true)
      feed_entry["favorite"][:n].first.should eql("1")
    end  
    
    response.should render_template("social/twitter/favorite")
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
       :search_type => SEARCH_TYPE[:saved]
    }
    
    if GNIP_ENABLED
      feed_entry, user_entry = dynamo_feed_for_tweet(@handle, sample_gnip_feed, true)
      feed_entry["favorite"][:n].first.should eql("1")
    end  
    
    
    feed_id = tweet_id
    Twitter::REST::Client.any_instance.stubs(:unfavorite).returns([feed_id])
    request.env["HTTP_ACCEPT"] = "application/javascript"
    post :unfavorite, {
       :item => {
        :stream_id => "#{@account.id}_#{@default_stream.id}",
        :feed_id => feed_id
       },
       :search_type => SEARCH_TYPE[:saved]
    }
    response.should render_template("social/twitter/unfavorite")
    
    if GNIP_ENABLED
      feed_entry, user_entry = dynamo_feed_for_tweet(@handle, sample_gnip_feed, true)
      feed_entry["favorite"][:n].first.should eql("0")
    end  
    
  end
  
  it "should get all the followers of the given screen name among the handles" do
    Twitter::REST::Client.any_instance.stubs(:follower_ids).returns(sample_follower_ids)
    request.env["HTTP_ACCEPT"] = "application/javascript"
    post :followers, {
       :screen_name => "Testing"
    }
    assigns['follow_hash'].should eql({@handle.screen_name => true})
    response.should render_template("social/twitter/followers")
  end

  it "should follow the handle on clicking the follow icon" do
    user_id = get_social_id
    Twitter::REST::Client.any_instance.stubs(:follow).returns([user_id])
    request.env["HTTP_ACCEPT"] = "application/javascript"
    post :follow, {
      :user => {
        :to_follow => "Testing",
        :screen_name => "Test"
      }
    }
    response.should render_template("social/twitter/follow")
  end
  
  it "should follow the handle on clicking the unfollow icon" do
    user_id = get_social_id
    Twitter::REST::Client.any_instance.stubs(:unfollow).returns([user_id])
    request.env["HTTP_ACCEPT"] = "application/javascript"
    post :unfollow, {
      :user => {
        :to_follow => "Testing",
        :screen_name => "Test"
      }
    }
    response.should render_template("social/twitter/unfollow")
  end
  
  it "should check if the user who is responding follows the accout to which being replyed to" do
    twt_handler = create_test_twitter_handle(@account)
    
    Twitter::REST::Client.any_instance.stubs(:friendship?).returns(true)
    
    post :user_following, {
                            :twitter_handle => twt_handler.id, 
                            :req_twt_id => "TestingTwitter", 
                          }
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
