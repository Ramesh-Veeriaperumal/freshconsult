require File.expand_path("#{File.dirname(__FILE__)}/../../spec_helper")

include GnipHelper
include DynamoHelper
include Social::Twitter::Constants
include Social::Dynamo::Twitter
include Social::Util

describe Social::StreamsController do
  integrate_views
  setup :activate_authlogic
  
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
    log_in(@agent)
  end
  
  describe "#stream_feeds" do
    it "should fetch all the streams(default/custom) on rendering the page" do
      all_streams = @agent.visible_social_streams
      default_streams = all_streams.select { |stream| stream.default_stream? }
      custom_streams  = all_streams.select { |stream| stream.custom_stream? }

      get :index
      response.should render_template("social/streams/index.html.erb")
      response.template_objects["streams"].should eql(default_streams)
      response.template_objects["custom_streams"].should eql(custom_streams)
    end
    
    it "should show all the old tweets on clicking on show more" do
      get :show_old, {
                        :social_streams => 
                          {
                            :stream_id => "#{@first_default_stream.id}", 
                            :first_feed_id => "0,0", 
                            :last_feed_id => "0,0"
                          }
                      }
     
      response.should render_template("social/streams/show_old.rjs")
    end
    
    it "should show all the old tweets on clicking on show more" do
      get :fetch_new, {
                            :social_streams => 
                                {
                                  :stream_id => "#{@first_default_stream.id}", 
                                  :first_feed_id => "0,0", 
                                  :last_feed_id => "0,0"
                                }
                          }
     
      response.should render_template("social/streams/fetch_new.rjs")
    end
  
    it "should fetch the top tweets from all the handles with latest first from dynamo when" do
      tweet_id1 = get_id
      tweet_id2 = tweet_id1 + 1
      tweet_id3 = tweet_id1 + 2
      tweet_id1, sample_gnip_feed1 = push_tweet_to_dynamo(tweet_id1, @first_rule, Time.now.utc.iso8601)
      tweet_id2, sample_gnip_feed2 = push_tweet_to_dynamo(tweet_id2, @first_rule, Time.now.ago(5.minutes).utc.iso8601)
      tweet_id3, sample_gnip_feed3 = push_tweet_to_dynamo(tweet_id3, @sec_rule, Time.now.ago(2.minutes).utc.iso8601)
      
      get :stream_feeds, {
                            :social_streams => 
                                {
                                  :stream_id => "#{@first_default_stream.id},#{@sec_default_stream.id}", 
                                  :first_feed_id => "0,0", 
                                  :last_feed_id => "0,0"
                                }
                          }
     
      response.should render_template("social/streams/stream_feeds.rjs")
      sorted_feeds = response.template_objects["sorted_feeds"]
      order = sorted_feeds.map{|a| a.stream_id if (a.stream_id == "#{@account.id}_#{@sec_default_stream.id}" or a.stream_id == "#{@account.id}_#{@first_default_stream.id}")}.compact
      order[0..2].should eql(["#{@account.id}_#{@first_default_stream.id}", "#{@account.id}_#{@sec_default_stream.id}", "#{@account.id}_#{@first_default_stream.id}"])
    end
  end
  
  describe "interactions" do
    it "should show the entire current interaction on clicking on a tweet feed" do
      tweet_id1 = get_id
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
                              :posted_time => "#{sample_gnip_feed3[:postedTime]}"
                            }, 
                            :search_type => "streams", 
                            :is_reply => "true", 
                            :is_retweet => "false", 
                        }
                        
      response.should render_template("social/streams/interactions.rjs")
      current_interactions = response.template_objects["interactions"][:current]
      current_interactions.length.should eql(4)
      current_interactions[0].feed_id.should eql("#{tweet_id1}")
      current_interactions[1].feed_id.should eql("#{tweet_id2}")
      current_interactions[2].feed_id.should eql("#{tweet_id3}")
      current_interactions[3].feed_id.should eql("#{tweet_id4}")
    end

    it "should show the the other interactions on clicking on a  tweet feed" do
      tweet_id1 = get_id
      tweet_id2 = tweet_id1 + 1
      tweet_id3 = tweet_id1 + 2
      
      tweet_id1, sample_gnip_feed1 = push_tweet_to_dynamo(tweet_id1, @first_rule, Time.now.utc.iso8601)
      tweet_id2, sample_gnip_feed2, sender2 = push_tweet_to_dynamo(tweet_id2, @first_rule,  Time.now.advance(:hours => +1).utc.iso8601, tweet_id1)
      tweet_id3, sample_gnip_feed3 = push_tweet_to_dynamo(tweet_id3, @first_rule,  Time.now.advance(:hours => +2).utc.iso8601, nil, sender2)
      
      sample_gnip_feed2.deep_symbolize_keys!
      
      get :interactions, {
                          :social_streams =>
                            {
                              :feed_id => "#{tweet_id3}",
                              :stream_id =>"#{@account.id}_#{@first_default_stream.id}", 
                              :user_id => "#{sender2}", 
                              :user_name => "GnipTestUser", 
                              :user_screen_name => "GnipTestUser", 
                              :user_image => "https://abs.twimg.com/sticky/default_profile_images/default_profile_5_normal.png", 
                              :in_reply_to =>"", 
                              :text => "#{sample_gnip_feed3[:body]}", 
                              :parent_feed_id => "#{tweet_id1}", 
                              :user_mentions => "TestingGnip", 
                              :posted_time => "#{sample_gnip_feed3[:postedTime]}"
                            }, 
                            :search_type => "streams", 
                            :is_reply => "true", 
                            :is_retweet => "false", 
                        }
                        
      response.should render_template("social/streams/interactions.rjs")
      other_interactions = response.template_objects["interactions"][:others]
      other_interactions.length.should eql(1)
      other_interactions[0].feed_id.should eql("#{tweet_id3}")
    end
  end
  
  it "should redirect to admin page if non handles are present" do
    Resque.inline = true
    GnipRule::Client.any_instance.stubs(:list).returns([]) unless GNIP_ENABLED
    Gnip::RuleClient.any_instance.stubs(:delete).returns(delete_response) unless GNIP_ENABLED
    @account.twitter_handles.destroy_all
    Resque.inline = false
    
    get :index
    response.should redirect_to admin_social_streams_url
  end

  describe "#index" do
    it "should fetch all the streams that are visible to the user" do
      all_streams = @agent.visible_social_streams
      default_streams = all_streams.select { |stream| stream.default_stream? }
      custom_streams  = all_streams.select { |stream| stream.custom_stream? }

      get :index
      response.should render_template("social/streams/index.html.erb")
      response.template_objects["streams"].should eql(default_streams)
      response.template_objects["custom_streams"].should eql(custom_streams)
    end
    
    it "should fetch all the streams that are visible to the where the stream is visible to marketing" do
      @first_default_stream.accessible.update_attributes(:access_type => 2)
      @first_default_stream.accessible.create_group_accesses([1])
      @sec_default_stream.accessible.update_attributes(:access_type => 2)
      @sec_default_stream.accessible.create_group_accesses([2])
      
      all_streams = @agent.visible_social_streams
      default_streams = all_streams.select { |stream| stream.default_stream? }
      custom_streams  = all_streams.select { |stream| stream.custom_stream? }

      get :index
      response.should render_template("social/streams/index.html.erb")
      response.template_objects["streams"].include?(@first_default_stream).should be_false
      response.template_objects["streams"].include?(@sec_default_stream).should be_false
      response.template_objects["custom_streams"].should eql(custom_streams)
    end
    
    it "should fetch all the streams that are visible to the user belonging to marketing" do
      AgentGroup.create(:user_id =>@agent.id, :group_id => 1)
      all_streams = @agent.visible_social_streams
      default_streams = all_streams.select { |stream| stream.default_stream? }
      custom_streams  = all_streams.select { |stream| stream.custom_stream? }

      get :index
      response.should render_template("social/streams/index.html.erb")
      response.template_objects["streams"].should eql(default_streams)
      response.template_objects["streams"].include?(@first_default_stream).should be_true
      response.template_objects["streams"].include?(@sec_default_stream).should be_false
      response.template_objects["custom_streams"].should eql(custom_streams)
    end
  end

  after(:all) do
    #Destroy the twitter handle
    Resque.inline = true
    GnipRule::Client.any_instance.stubs(:list).returns([]) unless GNIP_ENABLED
    GnipRule::Client.any_instance.stubs(:delete).returns(delete_response) unless GNIP_ENABLED
    # @handle.destroy
    # Social::Stream.destroy_all
    # Social::Tweet.destroy_all
    Resque.inline = false
  end  
end
