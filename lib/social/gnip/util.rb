module Social::Gnip::Util

  include Social::Util
  include Social::Twitter::Constants

  def apply_ticket_rules(account, args)
    twitter_handles = account.twitter_handles
    convert_hash = {}
    unless twitter_handles.blank?
      if args[:stream_id].starts_with?(TAG_PREFIX)
        stream = account.twitter_streams.find_by_id(args[:stream_id].gsub(TAG_PREFIX, ""))
        if stream
          @twitter_handle = stream.twitter_handle
          stream.update_volume_in_redis
          convert_hash = stream.check_ticket_rules(tweet_body(@tweet_obj))
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

  def smart_filter_convert_details(account, args)
    stream_id = args[:stream_id].gsub(TAG_PREFIX, "")
    stream = account.twitter_streams.find_by_id(stream_id)
    hash = {:tweet => true, :stream_id => stream_id}
    return hash unless stream
    #Smart filter is enabled for an account and due to some reasons if we disable it temporarily, we will convert all tweets to ticket if convert all tweets to ticket via smart filter is chosen
    #If smart filter with keywords is chosen, we wont apply smart filter and dont convert tweet to ticket
    if stream.should_check_smart_filter?
      unless Account.current.smart_filter_enabled? 
        if stream.smart_filter_rule.action_data[:with_keywords].to_i == 0
          hash.merge!({:smart_filter_response => SMART_FILTER_MANUAL_CONVERT_TO_TICKET})
          hash.merge!(convert_to_ticket_details(stream.smart_filter_rule))
        else 
          hash.merge!({
            :smart_filter_response => SMART_FILTER_MANUAL_DONT_CONVERT_TO_TICKET
          })
        end
        hash.merge!(:use_smart_filter_param => true) 
      else
        hash.merge!(:check_smart_filter => true) 
      end
    end
    hash
  end


  def convert_to_ticket_details(rule)
    hash = {}
    hash.merge!({
      :convert    => true,
      :group_id   => rule.action_data[:group_id],
      :product_id => rule.action_data[:product_id]
    })
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

  def apply_smart_filter(account, args)
    stream = account.twitter_streams.find_by_id(args[:stream_id].gsub(TAG_PREFIX, ""))
    @twitter_handle = stream.twitter_handle
    convert_hash = stream.check_smart_filter(tweet_body(@tweet_obj), @tweet_obj[:id].split(":").last.to_i, @twitter_handle.twitter_user_id)
  end 
end