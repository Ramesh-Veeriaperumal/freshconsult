module Redis::GnipRedisMethods

	include Social::Twitter::Constants
  include Social::Constants
  include Social::Util

  def update_tweet_time_in_redis(posted_time)
    sandbox(posted_time) do |last_entry, updated_time|
      unless last_entry[:end_time].nil? #Push if this is a valid disconnect period
        $redis_others.perform_redis_op("rpush", GNIP_DISCONNECT_LIST, last_entry[:parsed].to_json)
        last_entry[:start_time] = nil
      end
      last_entry[:parsed] = [updated_time, nil] if updated_time.to_i > last_entry[:start_time].to_i
      $redis_others.perform_redis_op("rpush", GNIP_DISCONNECT_LIST, last_entry[:parsed].to_json)
    end
  end

	def update_reconnect_time_in_redis(reconnect_time)
  queue_attributes = AwsWrapper::SqsV2.get_queue_attributes(SQS[:twitter_realtime_queue], ['ApproximateNumberOfMessages']) || {}
    params = {
      :reconnect_time => reconnect_time,
      queue_size: queue_attributes['ApproximateNumberOfMessages']
    }
		sandbox(reconnect_time) do |last_entry, updated_time|
  		unless last_entry[:parsed].nil?
        notify_social_dev("Frequent disconnects in Gnip Stream", params) if last_entry[:start_time] && last_entry[:end_time]
    		last_entry[:parsed] = [last_entry[:start_time], updated_time]
    		$redis_others.perform_redis_op("rpush", GNIP_DISCONNECT_LIST, last_entry[:parsed].to_json)
        notify_social_dev("Gnip Stream Reconnected", params)
  		else
        notify_social_dev("Gnip Reconnect list is nil", params)
  		end
  	end
	end


	def sandbox(time, &block) # time format "2012-03-19T22:10:56.000Z"
		updated_time = parse_time(time)
		last_entry = redis_last_entry
		block.call(last_entry, updated_time)
		return true
	end

	private

		def redis_last_entry
			hash = {}
			entry = $redis_others.perform_redis_op("rpop", GNIP_DISCONNECT_LIST)
			unless entry.nil?
				hash[:parsed] = JSON.parse(entry)
				hash[:start_time] = hash[:parsed].first
				hash[:end_time] = hash[:parsed].second
			end
			hash
		end

		def parse_time(time)
			updated_time = Time.parse(time).strftime("%Y%m%d%H%M")
		end
end
