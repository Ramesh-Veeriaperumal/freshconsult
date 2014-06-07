#require '../spec_helper'
require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module TwitterHelper
  
  def create_test_twitter_handle(test_account=nil)
    account = test_account.nil? ? Account.first : test_account
    account.make_current
    last_handle_id = "#{(Time.now.utc.to_f*100000).to_i}"
    @handle = Factory.build(:twitter_handle, :account_id => account.id, :twitter_user_id => last_handle_id)
    @handle.save()
    @handle.reload
    @handle
  end

  
  def create_test_custom_twitter_stream(test_account=nil)
    account = test_account.nil? ? Account.first : test_account
    account.make_current
    @custom_stream = Factory.build(:twitter_stream, :account_id => account.id, :social_id => @handle.id)
    @custom_stream.save()
    @custom_stream.reload
    @custom_stream.populate_accessible(Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all])
    @custom_stream
  end
  
  def create_test_ticket_rule(stream, test_account=nil)
    account = test_account.nil? ? Account.first : test_account
    account.make_current
    @ticket_rule = Factory.build(:ticket_rule, :account_id => account.id, :stream_id => stream.id)
    @ticket_rule.save
    @ticket_rule
  end
  
  def push_tweet_to_dynamo(rule = @rule, time = Time.now.utc.iso8601, reply = nil, sender_id = nil)
    sample_gnip_feed = sample_gnip_feed(rule, reply, time)
    tweet = sample_gnip_feed.to_json
    tweet_feed = Social::Gnip::TwitterFeed.new(tweet, $sqs_twitter)
    tweet_id = tweet_feed.tweet_id
    tweet_feed.twitter_user_id = sender_id if sender_id
    sender_id = tweet_feed.twitter_user_id
    tweet_feed.process
    [tweet_id, sample_gnip_feed, sender_id]
  end
  
  def sample_params_fd_item(tweet_id, stream_id, search_type, parent_tweet_id = nil)
    { 
        :item => {
                    :text => Faker::Lorem.words(10).join(" "), 
                    :in_reply_to => "",
                    :feed_id => tweet_id,
                    :stream_id => stream_id, 
                    :user_screen_name => "TestingGnip", 
                    :twitter_handle => @handle.id,
                    :user_image => "https://si0.twimg.com/profile_images/2816192909/db88b820451fa8498e8f3cf406675e13_normal.png",
                    :parent_feed_id => "#{parent_tweet_id}",
                    :user_mentions => "",
                    :posted_time => "#{Time.now.strftime("%a %b %d %T %z %Y")}"
                  },
                :search_type => search_type
      }
  end
  
  def sample_tweet_reply(stream_id, in_reply_to, search_type)
     { 
        :tweet => {
                    :body => "@ammucs91 #{Faker::Lorem.words(10).join(" ")}", 
                    :in_reply_to => in_reply_to
                  },         
                :stream_id => stream_id, 
                :screen_name => "GnipTestUser", 
                :search_type => search_type,
                :twitter_handle_id => @handle.id
      }
  end
  
  def sample_twitter_feed
    text = Faker::Lorem.words(10).join(" ")
    tweet_id = (Time.now.utc.to_f*100000).to_i
    twitter_feed = {
      "query" => "",
      "next_results" => "",
      "refresh_url" => "",
      "next_fetch_id" => "", 
      "created_at" => "#{Time.now.strftime("%a %b %d %T %z %Y")}",
      "id" => tweet_id,
      "id_str" => "#{tweet_id}",
      "in_reply_to_status_id_str" => "",
      "user" =>  {
          "id" => 2341632074,
          "id_str" => "2341632074",
          "name" => "Save the Hacker",
          "screen_name" => "savethehacker",
          "location" => "India",
          "description" => text,
          "url" => "http://t.co/vlcuq83QYM",
          "profile_image_url" => "https://si0.twimg.com/profile_images/2816192909/db88b820451fa8498e8f3cf406675e13_normal.png",
          "entities" =>  {
            "url" =>  {
              "urls" =>  [
                 {
                  "url" => "#{Faker::Internet.url}",
                  "expanded_url" => "#{Faker::Internet.url}",
                  "display_url" => "savethehacker.com",
                  "indices" =>  [
                    0,
                    22
                  ]
                }
              ]
            }
          }
        },
      "text" => text        
      } 
    twitter_feed
  end
  
  def update_db(stream)
    gnip_rule = stream.gnip_rule
    stream_data = stream.data
    data = {
      :rule_value => gnip_rule[:value],
      :rule_tag => gnip_rule[:tag]
    }
    stream_data.merge!(data)
    stream.update_attributes(:data => stream_data)
  end
  
  def sample_twitter_tweet_object
    attrs = {
      :id => (Time.now.utc.to_f*100000).to_i, 
      :retweet_count => 1
    }
    twitter_tweet = Twitter::Tweet.new(attrs)
    attrs.merge!(sample_twitter_feed.deep_symbolize_keys!)
    twitter_tweet
  end
  
   def sample_search_results_object
    attrs = {
      :id => (Time.now.utc.to_f*100000).to_i,
      :statuses => [],
      :search_metadata => {
                :max_id =>  250126199840518145,
                :since_id => 24012619984051000,
                :refresh_url => "?since_id=250126199840518145&q=%23freebandnames&result_type=mixed&include_entities=1",
                :next_results => "?max_id=249279667666817023&q=%23freebandnames&count=4&include_entities=1&result_type=mixed",
                :count => 4,
                :completed_in => 0.035,
                :since_id_str => "24012619984051000",
                :query => "%23freebandnames",
                :max_id_str => "250126199840518145"
              }
    }
    search_results = Twitter::SearchResults.new(attrs, "", "", "")
    search_results.attrs[:statuses][0] = sample_twitter_feed.deep_symbolize_keys!
    search_results.attrs[:statuses].first[:text] = "hello world"
    search_results
  end
  
  def add_response
    {
      "add" => {
                  :response=>true, 
                  :rule_value=> "", 
                  :rule_tag=> ""
          }
    }
  end
  
  def delete_response
    {
      "delete" => {
        :response=>true, 
        :rule_value => "",
        :rule_tag => ""
      }
    }
  end
  
  def sample_twitter_object(parent_id = "")
    attrs = sample_twitter_feed.deep_symbolize_keys
    attrs[:in_reply_to_user_id_str] = 2341632074
    twitter_feed = Twitter::Tweet.new(attrs)
  end
  
  def send_tweet_and_wait(feed, wait=20, fd_counter=nil)
    #Moking send tweet to sqs
    tweet_id = feed["id"].split(":").last.to_i
    tweet = wait_for_tweet(tweet_id, feed, wait, fd_counter)
  end

  def wait_for_tweet(tweet_id, feed, wait=60, fd_counter=nil)
    send_tweet(feed, fd_counter)
    wait_for = 1
    tweet = nil
    while wait_for <= wait
      tweet = Social::Tweet.find_by_tweet_id(tweet_id)
      if tweet.nil?
        sleep 1
        wait_for = wait_for + 1
      else
        break
      end
    end
    return tweet
  end

  def send_tweet(feed, fd_counter = nil)
    feed["fd_counter"] = fd_counter unless fd_counter.nil?
    gnip_msg = Social::Gnip::TwitterFeed.new(feed.to_json, $sqs_twitter) 
    gnip_msg.process
  end
  
  def sample_twitter_user(user_id)
    user_params = {
      :name => "GnipTesting",
      :id => "#{user_id}", 
      :screen_name => "GnipTesting", 
      :description => "#{Faker::Lorem.words(10).join(" ")}",
      :profile_image_url => "https://pbs.twimg.com/profile_images/2901592982/001829157606dbea8ac8db3c374ac506_normal.jpeg"
    }
    user = Twitter::User.new(user_params)
  end
  
  def sample_twitter_dm(twitter_id, screen_name, time)
    tweet_id = (Time.now.utc.to_f*100000).to_i
    user_params = {
      :id => "#{twitter_id}", 
      :screen_name => "#{screen_name}", 
      :profile_image_url => "https://pbs.twimg.com/profile_images/2901592982/001829157606dbea8ac8db3c374ac506_normal.jpeg"
    }
    #Check
    # sender = Twitter::User.new(user_params)
    dm_data = {
      :id => tweet_id,
      :id_str => "#{tweet_id}",
      :created_at => "#{time}" ,
      :text => "Testing Twitter DM message",
      :sender_id_str => "628160819",
      :sender => user_params
    }
    return dm_data
  end

end
