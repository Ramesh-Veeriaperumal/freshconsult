class Social::Gnip::TwitterFeed

  include Redis::GnipRedisMethods
  include Social::Gnip::Util
  include Social::Util
  include Gnip::Constants
  include Social::Twitter::Constants
  include Social::Twitter::TicketActions


  attr_accessor :tweet_obj, :posted_time, :tweet_id, :posted_time, :tweet_id, :in_reply_to, 
                  :twitter_user_id, :source, :tag_objs, :dynamo_helper


  alias :feed_id :tweet_id

  def initialize(tweet)

    begin
      @tweet_json = tweet
      @tweet_obj       = JSON.parse(tweet).symbolize_keys!
      @dynamo_helper   = Social::Dynamo::Twitter.new
      @source = SOURCE[:twitter]
      unless @tweet_obj.nil?
        matching_rules =  @tweet_obj[:gnip] ? @tweet_obj[:gnip]["matching_rules"] : []
        
        if @tweet_obj[:actor]
          @name              = @tweet_obj[:actor]["displayName"]
          @sender            = @tweet_obj[:actor]["preferredUsername"]
          @profile_image_url = @tweet_obj[:actor]["image"]
          @twitter_user_id   = @tweet_obj[:actor]["id"].split(":").last.to_i if @tweet_obj[:actor]["id"]
        end
        @in_reply_to   = @tweet_obj[:inReplyTo]["link"].split("/").last if @tweet_obj[:inReplyTo]
        @posted_time   = @tweet_obj[:postedTime]
        @tweet_id      = @tweet_obj[:id].split(":").last.to_i if @tweet_obj[:id]
        @retweet_count = @tweet_obj[:retweetCount]
        @tag_objs      = []
        
        
        matching_rules.each do |rule|
          tag_array  = rule["tag"].split(DELIMITER[:tags])
          tag_array.each do |tag|
            @tag_objs << Gnip::RuleTag.new(tag)
          end
        end
      end
    rescue TypeError, JSON::ParserError => e
      Rails.logger.debug "Error in parsing gnip feed json"
      Rails.logger.debug tweet.inspect
      NewRelic::Agent.notice_error(e, 
        { :custom_params => { :description => "JSON Parse error in gnip feed",
                              :tweet_obj => tweet }})
      @tweet_obj = nil
    end
  end

  def process
    notify_social_dev("Received a Gnip System message", @tweet_obj) if @tag_objs.empty?
    
    @tag_objs.each do |tag_obj|
      args = {
        :account_id => tag_obj.account_id,
        :stream_id  => tag_obj.stream_id
      }
      process_post(args) if post?
    end    
  end

  def feed_hash
    @tweet_obj
  end

  def process_tweet_to_ticket(account, args, convert_args)
    user = set_user if convert_args[:convert]
    convert_args[:oauth_credential] = get_oauth_credential(@twitter_handle) if @twitter_handle
    if reply?
      db_stream = args[:stream_id].gsub(TAG_PREFIX, "")
      tweet = account.tweets.find(:all, :conditions => ["tweet_id = ? AND stream_id =?", @in_reply_to, db_stream]).first
      unless tweet.blank?
        ticket  = tweet.get_ticket
        user = set_user unless user
        if ticket
          notable = add_as_note(@tweet_obj, @twitter_handle, :mention, ticket, user, convert_args) if @twitter_handle
        else 
          archive_ticket  = tweet.get_archive_ticket
          notable = add_as_ticket(@tweet_obj, @twitter_handle, :mention, convert_args, archive_ticket, user) if convert_args[:convert] && archive_ticket
        end
      else
        if convert_args[:convert]
          tweet_requeued = requeue(@tweet_obj)
          notable = add_as_ticket(@tweet_obj, @twitter_handle, :mention, convert_args, nil, user) if !tweet_requeued
        end
      end
    else
      notable = add_as_ticket(@tweet_obj, @twitter_handle, :mention, convert_args, nil, user) if convert_args[:convert]
    end
    if !tweet_requeued
      dynamo_feed_attr = fd_info(notable, user)
      dynamo_feed_attr.merge!(smart_filter_info(convert_args[:smart_filter_response]))
      update_tweet_time_in_redis(@posted_time)
      update_dynamo(args, convert_args, dynamo_feed_attr, @tweet_obj)
    end
  end

  def check_smart_filter(account, args)
    convert_hash = apply_smart_filter(account, args)
    process_tweet_to_ticket(account, args, convert_hash)
  end

  private

    def process_post(args)
      select_shard_and_account(args[:account_id]) do |account|
        if Account.current.suspended? || Account.current.mentions_to_tms_enabled?
          Rails.logger.info "Choosing not to process tweet here. Account ID :: #{args[:account_id]} :: Tweet ID: #{@tweet_id}"
          User.reset_current_user
          Account.reset_current_account
          return
        end
        notable = nil
        tweet_requeued = false

        convert_args = apply_ticket_rules(account, args)
        if self_tweeted?
          Rails.logger.debug "Self Tweeted : Tweet id : #{@tweet_id} : Resetting current user : #{User.current.try(:id)}"
          User.reset_current_user
          Account.reset_current_account
          return
        end
        if convert_args[:convert]
          process_tweet_to_ticket(account, args, convert_args)
        else
          smart_convert_args = smart_filter_convert_details(account, args)
          if smart_convert_args[:check_smart_filter]
            Social::Gnip::SmartFilterTweetToTicketWorker.perform_async(tweet: @tweet_json, data: args)
          elsif smart_convert_args[:use_smart_filter_param]
            process_tweet_to_ticket(account, args, smart_convert_args)
          else
            process_tweet_to_ticket(account, args, convert_args)
          end
        end
        Rails.logger.debug "Tweet id : #{@tweet_id} : Resetting current user : #{User.current.try(:id)}"
        User.reset_current_user
        Account.reset_current_account
      end
    rescue Exception => e
      Rails.logger.info "Error processing tweet: #{e}, account_id: #{args[:account_id]}, stream_id: #{args[:stream_id]}"
      raise e if Rails.env.production?
    end


  def reply?
    !@in_reply_to.blank?
  end

  def post?
    @tweet_obj[:verb].eql?("post")
  end

  def set_user
    user = get_twitter_user(@sender, @profile_image_url,  @name)
    Rails.logger.debug "Tweet id : #{@tweet_id}, User id : #{user.id}"
    user.make_current
  end
end
