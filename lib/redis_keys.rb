module RedisKeys

	HELPDESK_TICKET_FILTERS = "HELPDESK_TICKET_FILTERS:%{account_id}:%{user_id}:%{session_id}"
	HELPDESK_REPLY_DRAFTS = "HELPDESK_REPLY_DRAFTS:%{account_id}:%{user_id}:%{ticket_id}"
	PORTAL_PREVIEW = "PORTAL_PREVIEW:%{account_id}:%{user_id}:%{template_id}:%{label}"
	PORTAL_PREVIEW_PREFIX = "PORTAL_PREVIEW:%{account_id}:%{user_id}:*"


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

	def exists(key)
		begin
			$redis.exists(key)
		rescue Exception => e
        NewRelic::Agent.notice_error(e)
    end
	end

	def array_of_keys(pattern)
		begin
			$redis.keys(pattern)
		rescue Exception => e
        NewRelic::Agent.notice_error(e)
    end
	end

end