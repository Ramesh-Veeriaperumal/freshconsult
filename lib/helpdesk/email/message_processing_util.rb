module Helpdesk::Email::MessageProcessingUtil

	include Redis::OthersRedis
	include Redis::RedisKeys
	include Helpdesk::Email::Constants

	def safe_to_process?(state, created_time)
		if state.nil?
			return true
		elsif state == EMAIL_PROCESSING_STATE[:in_process].to_s
			return safe_now?(created_time)
		else
			return false
		end
	end

	def safe_to_archive?(state, created_time)
		if state == EMAIL_PROCESSING_STATE[:finished].to_s
			return safe_now?(created_time)
		else
			return false
		end
	end

	def safe_to_delete?(state)
		if state == EMAIL_PROCESSING_STATE[:archived].to_s
			return true
		else
			return false
		end
	end

	def safe_now?(created_time)
		(created_time.nil? || ((Time.now.utc - created_time.to_time.utc) > PROCESSING_TIMEOUT)) ? true : false
	end

	def set_processing_state(state, created_time, uid)
		message_status_key = MESSAGE_PROCESS_STATE % { :uid => uid }
		value = "#{state.to_s}:#{created_time.to_s}"
		old_state = get_set_others_redis_key(message_status_key, value, 4.days.seconds)
		if old_state.present?
			state, created_time = old_state.split(":",2)
			return safe_to_process?(state, created_time)
		else
			return true
		end
	end

	def get_message_processing_status(uid)
		message_status_key = MESSAGE_PROCESS_STATE % { :uid => uid }
		message_processing_info = get_others_redis_key(message_status_key)
		if message_processing_info.present?
			state, created_time = message_processing_info.split(":",2)
		end
		return state, created_time
	end

	def set_processed_ticket_data(ticket_data, uid)
		key = PROCESSED_TICKET_DATA % { :uid => uid }
		value = ticket_data.to_json
		set_others_redis_key(key,value,4.days.seconds) # expiry time can be same as visibility*no of retries (not sure)
	end
	
	def get_processed_ticket_data(uid)
		key = PROCESSED_TICKET_DATA % { :uid => uid }
		value = get_others_redis_key(key)
		ticket_data = JSON.parse(value)
		return Hash[ticket_data.collect{|k,v| [k, v.to_s]}]
	end

end