class Social::Gnip::Message

  include Redis::GnipRedisMethods
  include Social::TwitterUtil
  include Social::Gnip::Constants

  attr_accessor :posted_time, :tweet_id
  
  def initialize(tweet, queue)
    begin
      @tweet_obj = JSON.parse(tweet).symbolize_keys!
      @queue = queue
      unless @tweet_obj.nil?
        @matching_rules = @tweet_obj[:gnip]["matching_rules"] if @tweet_obj[:gnip]
        if @tweet_obj[:actor]
          @preferred_username = @tweet_obj[:actor]["preferredUsername"]
          @profile_image_url = @tweet_obj[:actor]["image"]
        end
        @in_reply_to = @tweet_obj[:inReplyTo]["link"].split("/").last if @tweet_obj[:inReplyTo]
        @posted_time = @tweet_obj[:postedTime]
        @tweet_id = @tweet_obj[:id].split(":").last.to_i if @tweet_obj[:id]
      end
    rescue TypeError, JSON::ParserError => e
      @tweet_obj = nil
      NewRelic::Agent.notice_error("Error in parsing JSON format", :custom_params => 
                                  {:msg => tweet })
    end
  end
  
  
  def process
    unless @matching_rules.blank?
      @matching_rules.each do |rule|
        tag_array = rule["tag"].to_s.split(DELIMITER[:tags])
        tag_array.each do |tag|
          tag_obj = Social::Gnip::RuleTag.new(tag)
          args = {
            :account_id => tag_obj.account_id,
            :handle_id => tag_obj.handle_id
          }
          convert(args)
          #Send the gnip data to Splunk for debugging
          Monitoring::RecordMetrics.register(@tweet_obj)
        end
      end
    else
       NewRelic::Agent.notice_error("System message recieved from Gnip",:custom_params => 
                                    {:msg => @tweet_obj.to_json })
    end
  end

 
  private
      
    def reply?
      !@in_reply_to.blank?
    end

    def post?
      @tweet_obj[:verb].eql?("post")
    end
    
    def realtime_enabled?(account)
      account.subscription.trial?
    end

    def convert(args)
      select_shard_and_account(args[:account_id]) do |account|
        #return unless realtime_enabled?(account)
        @twitter_handle = account.twitter_handles.find_by_id(args[:handle_id])
        if @twitter_handle && @twitter_handle.capture_mention_as_ticket
          if post?
            @sender = @preferred_username
            @account = @twitter_handle.account
            @user = get_twitter_user(@sender, @profile_image_url)
            if reply?
              tweet = @account.tweets.find_by_tweet_id(@in_reply_to)
              unless tweet.blank?
                ticket = tweet.get_ticket
                add_as_note(@tweet_obj, @twitter_handle, :mention, ticket, true)
              else
                requeue(@tweet_obj)
              end
            else
              add_as_ticket(@tweet_obj, @twitter_handle, :mention, true)
            end
            update_tweet_time_in_redis(@posted_time) unless @queue.approximate_number_of_messages > MSG_COUNT_FOR_UPDATING_REDIS
          end
        else
          puts "Could not find twitter_handle with id #{args[:handle_id]}"
          NewRelic::Agent.notice_error("Could not find twitter_handle",:custom_params => { 
            :args => args.inspect, :tweet => @tweet_obj.inspect})
        end
      end
    end

    def select_shard_and_account(account_id)
      begin
        Sharding.select_shard_of(account_id) do
          account = Account.find_by_id(account_id)
          account.make_current if account
        end
        account = Account.current
        yield(account)
      rescue ActiveRecord::RecordNotFound => e
        puts "Could not find account with id #{account_id}"
        NewRelic::Agent.notice_error(e, :custom_params => {:account_id => account_id,
          :description => "Could not find valid account id in gnip message"})
      end
    end
    
    def requeue(tweet_obj)
      options = {}
      if tweet_obj[:fd_counter] and tweet_obj[:fd_counter].to_i >= TIME[:max_time_in_sqs]
        add_as_ticket(tweet_obj, @twitter_handle, :mention, true)
      else
        tweet_obj[:fd_counter] = tweet_obj[:fd_counter].to_i + 60
        options[:delay_seconds] = tweet_obj[:fd_counter] 
        @queue.send_message(tweet_obj.to_json, options)
      end
    end
end
