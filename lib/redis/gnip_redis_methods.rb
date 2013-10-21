module Redis::GnipRedisMethods
	
	include Social::Gnip::Constants

	def update_tweet_time_in_redis(posted_time) 
		sandbox(posted_time) do |last_entry,updated_time|
			unless last_entry[:end_time].nil? #Push if this is a valid disconnect period
				$redis_others.rpush(GNIP_DISCONNECT_LIST, last_entry[:parsed].to_json)
				last_entry[:start_time] = nil
			end
			last_entry[:parsed] = [updated_time, nil] if updated_time.to_i > last_entry[:start_time].to_i
			$redis_others.rpush(GNIP_DISCONNECT_LIST, last_entry[:parsed].to_json)
		end
	end

	def update_reconnect_time_in_redis(reconnect_time)
		sandbox(reconnect_time) do |last_entry,updated_time|
  		unless last_entry[:parsed].nil?
    		NewRelic::Agent.notice_error("Frequent disconnects in Gnip Stream", :custom_params => {
            :reconnect_time => reconnect_time}) if last_entry[:start_time] && last_entry[:end_time]
    		last_entry[:parsed] = [last_entry[:start_time], updated_time]
    		$redis_others.rpush(GNIP_DISCONNECT_LIST, last_entry[:parsed].to_json)
    		NewRelic::Agent.notice_error("Gnip stream reconnected",
            :custom_params => {:reconnect_time => reconnect_time})
        SocialErrorsMailer.deliver_gnip_stream_reconnected({:reconnect_time => reconnect_time})
  		else
    		queue = $sqs_twitter
    		NewRelic::Agent.notice_error("Gnip reconnect list is nil", :custom_params => {
            :description => "Queue Size is #{queue.approximate_number_of_messages}"})
  		end
  	end
	end
	
	
	def sandbox(time,&block) # time format "2012-03-19T22:10:56.000Z"
		updated_time = parse_time(time)
		last_entry = redis_last_entry
		block.call(last_entry,updated_time)
		return true
	end
	
	private
	
		def redis_last_entry
			hash = {}
			entry = $redis_others.rpop(GNIP_DISCONNECT_LIST)		
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
