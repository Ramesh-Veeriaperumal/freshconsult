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
          Rails.logger.error "Received a rule tag without tag prefix S #{args}"
        end
      end
    end
    convert_hash.merge!(:tweet => true)
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
end