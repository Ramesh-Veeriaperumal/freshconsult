module RedisKeys

	HELPDESK_TICKET_FILTERS = "HELPDESK_TICKET_FILTERS:%{account_id}:%{user_id}:%{session_id}"
	HELPDESK_REPLY_DRAFTS = "HELPDESK_REPLY_DRAFTS:%{account_id}:%{user_id}:%{ticket_id}"
	HELPDESK_GAME_NOTIFICATIONS = "HELPDESK_GAME_NOTIFICATIONS:%{account_id}:%{user_id}"


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

	def set_key(key, value, expires = 86400)
		begin
			$redis.set(key, value)
			$redis.expire(key,expires) if expires
		rescue Exception => e
        NewRelic::Agent.notice_error(e)
    end
	end
end