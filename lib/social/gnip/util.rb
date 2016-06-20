module Social::Gnip::Util

  include Social::Util
  include Social::Twitter::Constants

  def can_convert(account, args)
    twitter_handles = account.twitter_handles
    convert_hash = {}
    unless twitter_handles.blank?
      if args[:stream_id].starts_with?(TAG_PREFIX)
        stream = account.twitter_streams.find_by_id(args[:stream_id].gsub(TAG_PREFIX, ""))
        if stream
          @twitter_handle = stream.twitter_handle
          stream.update_volume_in_redis
          convert_hash = stream.check_ticket_rules(@tweet_obj[:body])
        end
      else
        @twitter_handle = account.twitter_handles.find_by_id(args[:stream_id])
        #Possible dead code
        if @twitter_handle
          convert_hash = @twitter_handle.check_ticket_rules 
          notify_social_dev("Received a rule tag without tag prefix S", args )
        end
      end
    end
    convert_hash.merge!(:tweet => true)
  end

  def update_dynamo(args, convert_args, attributes, tweet_obj)
    if !convert_args[:stream_id].nil? and !@twitter_handle.nil? and post?
      if self_tweeted? and !self_tweeted_with_mention?
        attributes.merge!(:replied_by => "@#{@sender}")
      end
      dynamo_helper.update_tweet(args, attributes, self, tweet_obj) #it is bad to send self
    end
  end

  def requeue(tweet_obj)
    options = {}
    if tweet_obj[:fd_counter] and tweet_obj[:fd_counter].to_i >= TIME[:max_time_in_sqs]
      return false
    else
      tweet_obj[:fd_counter] = tweet_obj[:fd_counter].to_i + 60
      options[:delay_seconds] = tweet_obj[:fd_counter]
      $sqs_twitter.send_message(tweet_obj.to_json, options) unless Rails.env.test?
      return true
    end
  end

  def requeue_gnip_rule(env, response)
    rule_value = response[:rule_value]
    rule_tag   = response[:rule_tag]

    tag_array = rule_tag.split(DELIMITER[:tags])
    tag_array.each do |gnip_tag|
      tag = Gnip::RuleTag.new(gnip_tag)
      args = {
        :account_id => tag.account_id,
        :env  => env.to_a,
        :rule => {
          :value => rule_value,
          :tag   => gnip_tag
        },
        :action => RULE_ACTION[:add]
      }
      Social::Gnip::RuleWorker.perform_at(5.minutes.from_now, args)
    end
  end
  
  def self_tweeted_with_mention?
    return false if @twitter_handle.nil?
    self_tweeted? && @tweet_obj[:body].include?(@twitter_handle.formatted_handle) 
  end
  
  def self_tweeted?
    return false if @twitter_handle.nil?
    @sender.downcase.strip().eql?(@twitter_handle.screen_name.downcase.strip) if @twitter_handle
  end      

end
