#require '../spec_helper'
require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module TwitterHelper

  def create_test_twitter_handle(test_account=nil, deprecated=false)
    account = test_account.nil? ? Account.first : test_account
    account.make_current
    last_handle = Social::TwitterHandle.last
    last_handle_id = last_handle.nil? ? 1 : last_handle.twitter_user_id
    @handle = Factory.build(:twitter_handle, :account_id => account.id, :twitter_user_id => last_handle_id + 1)
    @handle.save()
    @handle.reload

    #Create a twitter handle the 'old' way
    unless deprecated
      @handle.cleanup
      @handle.reload
      @handle.populate_default_stream
      @handle.reload
      @stream = @handle.default_stream
      @stream.populate_ticket_rule([@handle.formatted_handle])
      @stream.reload
    end
    @handle
  end

  def send_tweet_and_wait(feed, wait=20)
    $sqs_twitter.send_message(feed.to_json)

    tweet_id = feed["id"].split(":").last.to_i
    tweet = wait_for_tweet(tweet_id, wait)
  end

  def wait_for_tweet(tweet_id, wait=60)
    wait_for = 1
    tweet = nil
    while wait_for <= wait
      tweet = Social::Tweet.find_by_tweet_id(tweet_id)
      if tweet.nil?
        sleep 2
        wait_for = wait_for + 2
      else
        break
      end
    end
    return tweet
  end
  
  def sample_twitter_dm(time)
    tweet_id = (Time.now.utc.to_f*100000).to_i
    user_params = {
      :id => 123, 
      :screen_name => "test_test", 
      :profile_image_url => "https://pbs.twimg.com/profile_images/2901592982/001829157606dbea8ac8db3c374ac506_normal.jpeg"
    }
    sender = Twitter::User.new(user_params)
    dm_data = {
      :id => tweet_id,
      :id_str => "#{tweet_id}",
      :created_at => "#{time}" ,
      :text => "Testing Twitter DM message",
      :sender_id_str => "628160819",
      :sender => sender
    }
    return dm_data
  end

end
