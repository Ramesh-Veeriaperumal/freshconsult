module RedisKeys

	HELPDESK_TICKET_FILTERS 			= "HELPDESK_TICKET_FILTERS:%{account_id}:%{user_id}:%{session_id}"
	HELPDESK_REPLY_DRAFTS 				= "HELPDESK_REPLY_DRAFTS:%{account_id}:%{user_id}:%{ticket_id}"

	HELPDESK_TICKET_ADJACENTS 			= "HELPDESK_TICKET_ADJACENTS:%{account_id}:%{user_id}:%{session_id}"
	HELPDESK_TICKET_ADJACENTS_META	 	= "HELPDESK_TICKET_ADJACENTS_META:%{account_id}:%{user_id}:%{session_id}"


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
		rescue Exception => e
	        NewRelic::Agent.notice_error(e)
	    end
	end

	def add_to_set(key, values)
		begin
			values.each do |val|
				puts "Adding #{val} to the list"
				$redis.sadd(key, val)
			end
			# $redis.sadd(key, *values)
			$redis.expire(key,expires) if expires
		rescue Exception => e
	        NewRelic::Agent.notice_error(e)
	    end

	end

	def set_members(key)
		begin
			$redis.smembers(key)
		rescue Exception => e
	        NewRelic::Agent.notice_error(e)
	    end

	end

	def list_push(key,values,direction = 'right')
		
		begin
			command = direction == 'right' ? 'rpush' : 'lpush'
			unless values.type == Array
				$redis.send(command, key, values)
			else
				values.each do |val|
					$redis.send(command, key, val)
				end
			end
		rescue Exception => e
	        NewRelic::Agent.notice_error(e)
	    end
	end

	def list_pull(key,direction = 'left')
		begin
			command = direction == 'right' ? 'rpull' : 'lpull'
			$redis.send(command, key)
		rescue Exception => e
	        NewRelic::Agent.notice_error(e)
	    end
	end


	def list_members(key)
		begin
			length = $redis.llen(key)
			$redis.lrange(key,0,length - 1)
		rescue Exception => e
	        NewRelic::Agent.notice_error(e)
	    end
	end

end