class Social::Twitter::Feed

  include Redis::GnipRedisMethods
  include Social::Twitter::Util
  include Social::Util
  include Gnip::Constants
  include Social::Twitter::DynamoUtil
  include Social::Twitter::Constants
  include Social::Constants

  attr_accessor :posted_time, :tweet_id

  def initialize(tweet, queue)
    begin
      @tweet_obj = JSON.parse(tweet).symbolize_keys!
      @queue = queue
      unless @tweet_obj.nil?
        Monitoring::RecordMetrics.register(@tweet_obj)

        @matching_rules = @tweet_obj[:gnip]["matching_rules"] if @tweet_obj[:gnip]
        if @tweet_obj[:actor]
          @sender = @tweet_obj[:actor]["preferredUsername"]
          @profile_image_url = @tweet_obj[:actor]["image"]
          @twitter_user_id = @tweet_obj[:actor]["id"].split(":").last.to_i if @tweet_obj[:actor]["id"]
        end

        @in_reply_to = @tweet_obj[:inReplyTo]["link"].split("/").last if @tweet_obj[:inReplyTo]
        @posted_time = @tweet_obj[:postedTime]
        @tweet_id = @tweet_obj[:id].split(":").last.to_i if @tweet_obj[:id]
      end
    rescue TypeError, JSON::ParserError => e
      @tweet_obj = nil
      puts "Error in parsing gnip feed json"
      NewRelic::Agent.notice_error("Error in parsing JSON format", :custom_params =>
                                  {:msg => tweet})
    end
  end

  def process
    unless @matching_rules.blank? or @matching_rules.nil?
      @matching_rules.each do |rule|
        tag_array = rule["tag"].to_s.split(DELIMITER[:tags])
        tag_array.each do |tag|
          tag_obj = Gnip::RuleTag.new(tag)
          args = {
            :account_id => tag_obj.account_id,
            :stream_id => tag_obj.stream_id
          }
          convert(args)
        end
      end
    else
      notify_social_dev("Received a Gnip System message", @tweet_obj)
    end
  end


  private

    def reply?
      !@in_reply_to.blank?
    end

    def post?
      @tweet_obj[:verb].eql?("post")
    end

    def can_convert(account, args)
      twitter_handles = account.twitter_handles
      convert_hash = {}
      unless twitter_handles.blank?
        if args[:stream_id].starts_with?(TAG_PREFIX)
          stream = account.twitter_streams.find_by_id(args[:stream_id].gsub(TAG_PREFIX, ""))
          if stream
            @twitter_handle = stream.twitter_handle
            convert_hash = stream.check_ticket_rules(@tweet_obj[:body])
          end
        else
          @twitter_handle = account.twitter_handles.find_by_id(args[:stream_id])
          convert_hash = @twitter_handle.check_ticket_rules if @twitter_handle
        end
      end
      convert_hash.merge!(:gnip => true)
    end

    def convert(args)
      select_shard_and_account(args[:account_id]) do |account|
        dynamo_feed_attr = {
          :fd_link => nil, 
          :fd_user => nil
        }
        notable = nil

        convert_args = can_convert(account, args)        

        if convert_args[:convert] and post?
          @account = @twitter_handle.account
          @user = get_twitter_user(@sender, @profile_image_url)
          dynamo_feed_attr[:fd_user] = @user.id
          if reply?
            tweet = @account.tweets.find_by_tweet_id(@in_reply_to)
            unless tweet.blank?
              ticket = tweet.get_ticket
              notable = add_as_note(@tweet_obj, @twitter_handle, :mention, ticket, convert_args)
            else
              notable = add_as_ticket(@tweet_obj, @twitter_handle, :mention, convert_args) unless requeue(@tweet_obj)
            end
          else
            notable = add_as_ticket(@tweet_obj, @twitter_handle, :mention, convert_args)
          end
          dynamo_feed_attr[:fd_link] = helpdesk_ticket_link(notable)
          update_tweet_time_in_redis(@posted_time) unless @queue.approximate_number_of_messages > MSG_COUNT_FOR_UPDATING_REDIS
        else
          user = account.all_users.find_by_twitter_id(@sender)
          dynamo_feed_attr[:fd_user] = user.id unless user.nil?
        end
        
        update_dynamo(args, convert_args, dynamo_feed_attr)
      end
    end

    def requeue(tweet_obj)
      options = {}
      if tweet_obj[:fd_counter] and tweet_obj[:fd_counter].to_i >= TIME[:max_time_in_sqs]
        return false
      else
        tweet_obj[:fd_counter] = tweet_obj[:fd_counter].to_i + 60
        options[:delay_seconds] = tweet_obj[:fd_counter]
        @queue.send_message(tweet_obj.to_json, options)
        return true
      end
    end
    
    def helpdesk_ticket_link(item)
      return nil if item.nil? or item.id.nil? #if the ticket/note save failed or we requeue the feed
      if item.is_a?(Helpdesk::Ticket)
        link = "#{item.display_id}"
      elsif item.is_a?(Helpdesk::Note)
        ticket = item.notable
        link = "#{ticket.display_id}#note#{item.id}"
      end
    end

    def update_dynamo(args, convert_args, attributes)
      #Valid account_id, stream_id
      #Also avoid updating for twitter_handle feeds
      if !convert_args[:stream_id].nil? and !@twitter_handle.nil? and post?
        update_tweet(args, attributes)
      end
    end

end
