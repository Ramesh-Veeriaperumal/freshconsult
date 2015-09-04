class Social::Gnip::TwitterFeed

  include Redis::GnipRedisMethods
  include Social::Gnip::Util
  include Social::Util
  include Gnip::Constants
  include Social::Twitter::Constants
  include Social::Twitter::TicketActions

  attr_accessor :tweet_obj, :posted_time, :tweet_id, :posted_time, :tweet_id, :in_reply_to, :twitter_user_id, :source

  alias :feed_id :tweet_id

  def initialize(tweet, queue)
    begin
      @tweet_obj = JSON.parse(tweet).symbolize_keys!
      @queue  = queue
      @source = SOURCE[:twitter]
      unless @tweet_obj.nil?
        @matching_rules = @tweet_obj[:gnip]["matching_rules"] if @tweet_obj[:gnip]
        if @tweet_obj[:actor]
          @sender            = @tweet_obj[:actor]["preferredUsername"]
          @profile_image_url = @tweet_obj[:actor]["image"]
          @twitter_user_id   = @tweet_obj[:actor]["id"].split(":").last.to_i if @tweet_obj[:actor]["id"]
        end
        @in_reply_to   = @tweet_obj[:inReplyTo]["link"].split("/").last if @tweet_obj[:inReplyTo]
        @posted_time   = @tweet_obj[:postedTime]
        @tweet_id      = @tweet_obj[:id].split(":").last.to_i if @tweet_obj[:id]
        @retweet_count = @tweet_obj[:retweetCount]
      end
    rescue TypeError, JSON::ParserError => e
      @tweet_obj = nil
      Rails.logger.debug "Error in parsing gnip feed json"
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
            :stream_id  => tag_obj.stream_id
          }
          process_post(args) if post?
        end
      end
    else
      notify_social_dev("Received a Gnip System message", @tweet_obj)
    end
  end

  def feed_hash
    @tweet_obj
  end


  private

  def process_post(args)
    select_shard_and_account(args[:account_id]) do |account|
      notable = nil
      tweet_requeued = false
      convert_args = can_convert(account, args)
      convert_args[:convert] = false if self_tweeted?
      user = set_user if convert_args[:convert]
      
      if reply?
        db_stream = args[:stream_id].gsub(TAG_PREFIX, "")
        tweet = account.tweets.find(:all, :conditions => ["tweet_id = ? AND stream_id =?", @in_reply_to, db_stream]).first
        unless tweet.blank?
          ticket  = tweet.get_ticket
          if ticket
            user = set_user unless user
            notable = add_as_note(@tweet_obj, @twitter_handle, :mention, ticket, user, convert_args) if @twitter_handle
          else 
            archive_ticket  = tweet.get_archive_ticket
            notable = add_as_ticket(@tweet_obj, @twitter_handle, :mention, convert_args,archive_ticket) if convert_args[:convert] && archive_ticket
          end
        else
          if convert_args[:convert]
            tweet_requeued = requeue(@tweet_obj)
            notable = add_as_ticket(@tweet_obj, @twitter_handle, :mention, convert_args) if !tweet_requeued
          end
        end
      else
        notable = add_as_ticket(@tweet_obj, @twitter_handle, :mention, convert_args) if convert_args[:convert]
      end

      if !tweet_requeued
        dynamo_feed_attr = fd_info(notable, user)
        update_tweet_time_in_redis(@posted_time) #unless @queue.approximate_number_of_messages > MSG_COUNT_FOR_UPDATING_REDIS
        update_dynamo(args, convert_args, dynamo_feed_attr, @tweet_obj)
      end

      User.reset_current_user
      Account.reset_current_account
    end
  end

  def reply?
    !@in_reply_to.blank?
  end

  def post?
    @tweet_obj[:verb].eql?("post")
  end

  def set_user
    user = get_twitter_user(@sender, @profile_image_url)
    user.make_current
  end
end
