module RedisKeys

	HELPDESK_TICKET_FILTERS = "HELPDESK_TICKET_FILTERS:%{account_id}:%{user_id}:%{session_id}"
	HELPDESK_REPLY_DRAFTS = "HELPDESK_REPLY_DRAFTS:%{account_id}:%{user_id}:%{ticket_id}"
	HELPDESK_GAME_NOTIFICATIONS = "HELPDESK_GAME_NOTIFICATIONS:%{account_id}:%{user_id}"
	HELPDESK_TICKET_ADJACENTS 			= "HELPDESK_TICKET_ADJACENTS:%{account_id}:%{user_id}:%{session_id}"
	HELPDESK_TICKET_ADJACENTS_META	 	= "HELPDESK_TICKET_ADJACENTS_META:%{account_id}:%{user_id}:%{session_id}"
	INTEGRATIONS_JIRA_NOTIFICATION = "INTEGRATIONS_JIRA_NOTIFY:%{account_id}:%{local_integratable_id}:%{remote_integratable_id}"
	INTEGRATIONS_LOGMEIN = "INTEGRATIONS_LOGMEIN:%{account_id}:%{ticket_id}"
	HELPDESK_TICKET_UPDATED_NODE_MSG    = "{\"ticket_id\":\"%{ticket_id}\",\"agent\":\"%{agent_name}\",\"type\":\"%{type}\"}"
	
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

	def add_to_set(key, values, expires = 86400)
		begin
			values.each do |val|
				$redis.sadd(key, val)
			end
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

	def list_push(key,values,direction = 'right', expires = 3600)
		
		begin
			command = direction == 'right' ? 'rpush' : 'lpush'
			unless values.type == Array
				$redis.send(command, key, values)
			else
				values.each do |val|
					$redis.send(command, key, val)
				end
			end
			$redis.expire(key,expires) if expires
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

	def publish_to_channel channel, message
	  begin
	  	return $redis.publish(channel, message)
	  rescue Exception => e
	  	NewRelic::Agent.notice_error(e)
	  end
	end
end