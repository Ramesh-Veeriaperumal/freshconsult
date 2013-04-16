module RedisKeys

	HELPDESK_TICKET_FILTERS = "HELPDESK_TICKET_FILTERS:%{account_id}:%{user_id}:%{session_id}"
	HELPDESK_REPLY_DRAFTS = "HELPDESK_REPLY_DRAFTS:%{account_id}:%{user_id}:%{ticket_id}"
	HELPDESK_GAME_NOTIFICATIONS = "HELPDESK_GAME_NOTIFICATIONS:%{account_id}:%{user_id}"
	HELPDESK_TICKET_ADJACENTS 			= "HELPDESK_TICKET_ADJACENTS:%{account_id}:%{user_id}:%{session_id}"
	HELPDESK_TICKET_ADJACENTS_META	 	= "HELPDESK_TICKET_ADJACENTS_META:%{account_id}:%{user_id}:%{session_id}"
	INTEGRATIONS_JIRA_NOTIFICATION = "INTEGRATIONS_JIRA_NOTIFY:%{account_id}:%{local_integratable_id}:%{remote_integratable_id}"
	INTEGRATIONS_LOGMEIN = "INTEGRATIONS_LOGMEIN:%{account_id}:%{ticket_id}"
	HELPDESK_TICKET_UPDATED_NODE_MSG    = "{\"ticket_id\":%{ticket_id},\"agent\":\"%{agent_name}\",\"type\":\"%{type}\"}"
	HELPDESK_TKTSHOW_VERSION = "HELPDESK_TKTSHOW_VERSION:%{account_id}:%{user_id}"
	EMAIL_TICKET_ID = "EMAIL_TICKET_ID:%{account_id}:%{message_id}"
	PORTAL_PREVIEW = "PORTAL_PREVIEW:%{account_id}:%{user_id}:%{template_id}:%{label}"
	IS_PREVIEW = "IS_PREVIEW:%{account_id}:%{user_id}:%{portal_id}"
	PREVIEW_URL = "PREVIEW_URL:%{account_id}:%{user_id}:%{portal_id}"
	GROUP_AGENT_TICKET_ASSIGNMENT = "GROUP_AGENT_TICKET_ASSIGNMENT:%{account_id}:%{group_id}"

	PORTAL_CACHE_ENABLED = "PORTAL_CACHE_ENABLED"
	PORTAL_CACHE_VERSION = "PORTAL_CACHE_VERSION:%{account_id}"
	API_THROTTLER  = "API_THROTTLER:%{host}"
	
	def newrelic_begin_rescue
    begin
      yield
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      return
    end 
  end

	def enqueue_worker(worker, *args)
		newrelic_begin_rescue { Resque.enqueue(worker, *args) }
	end

	def increment(key)
		newrelic_begin_rescue { $redis.INCR(key) }
	end

	def get_key(key)
		newrelic_begin_rescue { $redis.get(key) }
	end

	def remove_key(key)
		newrelic_begin_rescue { $redis.del(key) }
	end

	def set_key(key, value, expires = 86400)
		newrelic_begin_rescue do
			$redis.set(key, value)
			$redis.expire(key,expires) if expires
	  end
	end

	def set_expiry(key, expires)
		newrelic_begin_rescue do
			$redis.expire(key, expires)
		end
	end

	def get_expiry(key)
		newrelic_begin_rescue { $redis.ttl(key) }
	end

	def add_to_set(key, values, expires = 86400)
		newrelic_begin_rescue do
			values.each do |val|
				$redis.sadd(key, val)
			end
			 $redis.expire(key,expires) if expires
	  end
	end

	def set_members(key)
		newrelic_begin_rescue { $redis.smembers(key) }
	end

	def list_push(key,values,direction = 'right', expires = 3600)
		newrelic_begin_rescue do
			command = direction == 'right' ? 'rpush' : 'lpush'
			unless values.type == Array
				$redis.send(command, key, values)
			else
				values.each do |val|
					$redis.send(command, key, val)
				end
			end
			$redis.expire(key,expires) if expires
	  end
	end

	def list_pull(key,direction = 'left')
		newrelic_begin_rescue do
			command = direction == 'right' ? 'rpull' : 'lpull'
			$redis.send(command, key)
	  end
	end

	def list_members(key)
		newrelic_begin_rescue do
			length = $redis.llen(key)
			$redis.lrange(key,0,length - 1)
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

	def publish_to_channel channel, message
		newrelic_begin_rescue do
	  	return $redis.publish(channel, message)
	  end
	end
end