module TwitterHelper
  
  def create_test_twitter_handle(test_account=nil)
    account = test_account.nil? ? Account.first : test_account
    handle = FactoryGirl.build(:twitter_handle, :account_id => account.id)
    handle.save()
    handle.reload
    handle
  end

  
  def create_test_custom_twitter_stream(handle)
    account = @account
    custom_stream = FactoryGirl.build(:twitter_stream, :account_id => account.id, :social_id => handle.id)
    custom_stream.save()
    custom_stream.reload
    custom_stream.populate_accessible(Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all])
    custom_stream
  end
  
  def create_test_ticket_rule(stream, test_account=nil)
    account = test_account.nil? ? Account.first : test_account
    ticket_rule = FactoryGirl.build(:ticket_rule, :account_id => account.id, :stream_id => stream.id)
    ticket_rule.filter_data = {:includes => ['@TestingGnip']}
    ticket_rule.save
    ticket_rule
  end
  
  def push_tweet_to_dynamo(tweet_id, rule = @rule, time = Time.now.utc.iso8601, reply = nil, sender_id = nil)
    sample_gnip_feed = sample_gnip_feed(rule, reply, time)
    sample_gnip_feed["id"] = "tag:search.twitter.com,2005:#{tweet_id}"
    tweet = sample_gnip_feed.to_json
    tweet_feed = Social::Gnip::TwitterFeed.new(tweet, $sqs_twitter)
    tweet_id = tweet_feed.tweet_id
    tweet_feed.twitter_user_id = sender_id if sender_id
    sender_id = tweet_feed.twitter_user_id
    tweet_feed.process
    [tweet_id, sample_gnip_feed, sender_id]
  end
  
  def sample_dynamo_query_params(tweet_id)
    {
      :item => {
        "stream_id" => {:s=>"#{@account.id}_#{@default_stream.id}"}, 
        "feed_ids" => {:ss=>["#{tweet_id}"]}, 
        "object_id" => {:s=>"feed:#{tweet_id}"}
      }
    }
  end
  
  def sample_tweets_array(feeds = true)
    tweet_array = {
      "statuses" => []
    }
    tweets = []
    
    if feeds
      #Customer tweets
      10.times do |n|
        tweet =  sample_twitter_feed
        tweet["text"] = "http://helloworld.com" if n == 8
        tweet["user"]["description"] = "TestingGnip" if n == 9
        tweets << tweet 
      end
      
      #Brand tweet
      10.times do |n|
        tweet = sample_twitter_feed
        tweet["user"]["screen_name"] = "TestingGnip"
        tweet["in_reply_to_status_id"] = tweets[n]["id"] if n==2
        tweets << tweet
      end   
      
      tweet_array["statuses"] = tweets
    end
    response = {:body => tweet_array.to_json}
    faraday_response = Faraday::Response.new(response)
    OAuth2::Response.new(faraday_response)
  end
  
  def sample_follower_ids
    cursor = Class.new do
              attr_accessor :attrs
            end
    cursor = cursor.new
    cursor.attrs = {:ids => [@handle.twitter_user_id]}
    cursor
  end
  
  def sample_dynamo_query_params
    {
      :member =>
            [
              {
                "stream_id"=>{:s=>"#{@account.id}_#{@default_stream.id}"}, 
                "feed_id"=>{:s=>"140264336660376"}, 
                "posted_time"=>{:ss=>["1402643366000"]}, 
                "parent_feed_id"=>{:ss=>["140264336660376"]
              }, 
              "source" => {:s=>"Twitter"}, 
              "in_conversation" => {:n=>"0"}, 
              "data" => {
                :ss=>[
                        "{\"body\":\"@TestingGnip accusamus aut saepe sint voluptatem autem amet eaque suscipit eos qui consectetur delectus nesciunt dolore sed provident quasi consequuntur recusandae\",\"retweetCount\":2,\"gnip\":{\"matching_rules\":[{\"value\":\"(@TestingGnip OR from:TestingGnip ) -is:retweet\",\"tag\":\"S22_1\"}],\"klout_score\":\"0\"},\"actor\":{\"preferredUsername\":\"GnipTestUser\",\"image\":\"https://si0.twimg.com/profile_images/2816192909/db88b820451fa8498e8f3cf406675e13_normal.png\",\"id\":\"id:twitter.com:140264336660398\",\"displayName\":\"Gnip Test User\"},\"verb\":\"post\",\"postedTime\":\"2014-06-13T07:09:26Z\",\"id\":\"tag:search.twitter.com,2005:140264336660376\"}"
                      ]
                      }, 
              "is_replied"=>{:n=>"0"}
              }
            ], 
            :count=>1
    }

  end
  
  def sample_interactions_batch_get(tweet_id)
    [
      {
        :responses => 
            {
              "#{Social::DynamoHelper.select_table("feeds", Time.now)}"=>[
                {
                  "stream_id"=>{:s=>"#{@account.id}_#{@default_stream.id}"}, 
                  "feed_id"=>{:s=>"#{tweet_id}"}, 
                  "posted_time"=>{:ss=>["#{tweet_id}"]
                }, 
              "parent_feed_id"=>{:ss=>["#{tweet_id}"]}, 
              "source"=>{:s=>"Twitter"}, 
              "in_conversation"=>{:n=>"0"}, 
              "data"=>{:ss=>["{\"body\":\"@TestingGnip quae animi consequatur omnis repudiandae unde et cum molestiae nihil qui asperiores voluptas quibusdam quidem rerum aut vero eum fugit\",\"retweetCount\":2,\"gnip\":{\"matching_rules\":[{\"value\":\"(@TestingGnip OR from:TestingGnip ) -is:retweet\",\"tag\":\"S46_1\"}],\"klout_score\":\"0\"},\"actor\":{\"preferredUsername\":\"GnipTestUser\",\"image\":\"https://si0.twimg.com/profile_images/2816192909/db88b820451fa8498e8f3cf406675e13_normal.png\",\"id\":\"id:twitter.com:140265255013396\",\"displayName\":\"Gnip Test User\"},\"verb\":\"post\",\"postedTime\":\"2014-06-13T09:42:30Z\",\"id\":\"tag:search.twitter.com,2005:140265255013371\"}"]}, 
              "is_replied"=>{:n=>"0"}
              }
            ]
            }, 
            :unprocessed_keys=>{}
      }
    ]
  end
  
  def dynamo_update_attributes(tweet_id)
    {
      :attributes=>{
        "stream_id"=>{:s=>"#{@account.id}_#{@default_stream.id}"}, 
        "fd_user"=>{:ss=>["6"]}, 
        "feed_id"=>{:s=>"#{tweet_id}"}, 
        "posted_time"=>{:ss=>["#{tweet_id}"]}, 
        "parent_feed_id"=>{:ss=>["#{tweet_id}"]}, 
        "source"=>{:s=>"Twitter"}, 
        "in_conversation"=>{:n=>"1"}, 
        "fd_link"=>{:ss=>["2"]}, 
        "data"=>{:ss=>["{\"body\":\"@TestingGnip et aperiam ipsa assumenda neque sit non repellat deserunt natus dolorem perferendis magni dolores odio quo ab quia ut nam\",\"retweetCount\":2,\"gnip\":{\"matching_rules\":[{\"value\":\"(@TestingGnip OR from:TestingGnip ) -is:retweet\",\"tag\":\"S67_1\"}],\"klout_score\":\"0\"},\"actor\":{\"preferredUsername\":\"GnipTestUser\",\"image\":\"https://si0.twimg.com/profile_images/2816192909/db88b820451fa8498e8f3cf406675e13_normal.png\",\"id\":\"id:twitter.com:140265655633631\",\"displayName\":\"Gnip Test User\"},\"verb\":\"post\",\"postedTime\":\"2014-06-13T10:49:16Z\",\"id\":\"tag:search.twitter.com,2005:140265655633605\"}"]}, 
        "is_replied"=>{:n=>"1"}
      }
    }

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
                    :posted_time => "#{Time.now.utc.strftime("%a %b %d %T %z %Y")}"
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
    tweet_id = get_social_id
    in_reply_to_status_id_str = (1.days.ago.utc.to_f*100000).to_i
    twitter_feed = {
      "query" => "",
      "next_results" => "",
      "refresh_url" => "",
      "next_fetch_id" => "", 
      "created_at" => "#{Time.now.utc.strftime("%a %b %d %T %z %Y")}",
      "id" => tweet_id,
      "id_str" => "#{tweet_id}",
      "in_reply_to_status_id_str" => "#{in_reply_to_status_id_str}",
      "user" =>  {
          "id" => "2341632074",
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
      :id => get_social_id, 
      :retweet_count => 1
    }
    twitter_tweet = Twitter::Tweet.new(attrs)
    attrs.merge!(sample_twitter_feed.deep_symbolize_keys!)
    twitter_tweet
  end
  
   def sample_search_results_object
    attrs = {
      :id => get_social_id,
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
    Net::HTTPResponse.new("http",201,"")
  end
  
  def delete_response
    Net::HTTPResponse.new("http",200,"")
  end
  
  def sample_twitter_object(parent_id = "")
    attrs = sample_twitter_feed.deep_symbolize_keys
    attrs[:in_reply_to_user_id_str] = "2341632074"
    twitter_feed = Twitter::Tweet.new(attrs)
  end
  
  def send_tweet_and_wait(feed, fd_counter=nil)
    #Moking send tweet to sqs
    tweet_id = feed["id"].split(":").last.to_i
    tweet = wait_for_tweet(tweet_id, feed, fd_counter)
  end

  def wait_for_tweet(tweet_id, feed, fd_counter=nil)
    send_tweet(feed, fd_counter)
    wait_for = 1
    tweet = nil
    tweet = @account.tweets.find_by_tweet_id(tweet_id)
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
    tweet_id = get_social_id
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

  def get_social_id
    (Time.now.utc.to_f*1000000).to_i
  end

end
