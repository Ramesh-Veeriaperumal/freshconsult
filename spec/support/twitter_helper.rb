#require '../spec_helper'
require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module TwitterHelper

  def create_test_twitter_handle(test_account=nil, deprecated=false)
    account = test_account.nil? ? Account.first : test_account
    account.make_current
    last_handle_id = "#{(Time.now.utc.to_f*100000).to_i}"
    @handle = Factory.build(:twitter_handle, :account_id => account.id, :twitter_user_id => last_handle_id)
    @handle.save()
    @handle.reload

    #Create a twitter handle the 'old' way
    unless deprecated
      @handle.cleanup
      @handle.reload
      @handle.build_default_streams
      @handle.build_custom_streams
      @handle.reload
      @streams = @handle.twitter_streams
      @streams.each do  |stream|
        unless stream.data[:kind] == "Custom"
          stream.populate_ticket_rule(nil, [@handle.formatted_handle])
        end
      end
      @streams.reload
    end
    @handle
  end

  def send_tweet_and_wait(feed, fd_counter=nil)
    #Moking send tweet to sqs
    tweet_id = feed["id"].split(":").last.to_i
    send_tweet(feed, fd_counter)
    tweet = Social::Tweet.find_by_tweet_id(tweet_id)    
    return tweet
  end

  def send_tweet(feed, fd_counter = nil)
    feed["fd_counter"] = fd_counter unless fd_counter.nil?
    gnip_msg = Social::Gnip::TwitterFeed.new(feed.to_json, $sqs_twitter) 
    gnip_msg.process
  end
  
  def sample_twitter_dm(twitter_id, screen_name, time)
    tweet_id = (Time.now.utc.to_f*100000).to_i
    user_params = {
      :id => "#{twitter_id}", 
      :screen_name => "#{screen_name}", 
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
  
  def update_handle_rule(handle)
    handle.update_attributes(:rule_value => "@TestingGnip", :rule_tag => "#{handle.id}_#{handle.account.id}")
  end
  
  def update_stream_rule(stream)
    gnip_rule = stream.gnip_rule
    stream_data = stream.data
    data = {
      :rule_value => gnip_rule[:value],
      :rule_tag => gnip_rule[:tag]
    }
    stream_data.merge!(data)
    stream.update_attributes(:data => stream_data)
  end
end
