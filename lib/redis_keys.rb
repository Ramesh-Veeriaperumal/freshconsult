module RedisKeys

	HELPDESK_TICKET_FILTERS = "HELPDESK_TICKET_FILTERS:%{account_id}:%{user_id}:%{session_id}"


	def get_key(key)
		begin
			$redis.get(key)
		rescue Exception => e
        NewRelic::Agent.notice_error(e)
    end	
	end

	def remove_key(key)
		begin
			$redis.del(key)
		rescue Exception => e
        NewRelic::Agent.notice_error(e)
    end
	end

	def set_key(key, value, expires)
		begin
			$redis.set(key, value)
			$redis.expire(key,expires) if expires
		rescue Exception => e
        NewRelic::Agent.notice_error(e)
    end
	end
end