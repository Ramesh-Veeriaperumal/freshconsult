module Redis::RedisKeys

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
	#AUTH_REDIRECT_CONFIG = "AUTH_REDIRECT:%{account_id}:%{user_id}:%{provider}:%{auth}"
	SSO_AUTH_REDIRECT_OAUTH = "AUTH_REDIRECT:%{account_id}:%{user_id}:%{provider}:oauth"
	APPS_AUTH_REDIRECT_OAUTH = "AUTH_REDIRECT:%{account_id}:%{provider}:oauth"
	AUTH_REDIRECT_GOOGLE_OPENID = "AUTH_REDIRECT:%{account_id}:google:open_id:%{token}"
	
	REPORT_STATS_REGENERATE_KEY = "REPORT_STATS_REGENERATE:%{account_id}" # set of dates for which stats regeneration will happen
	REPORT_STATS_EXPORT_HASH = "REPORT_STATS_EXPORT_HASH:%{account_id}" # last export date, last archive job id and last regen job id
	ENTERPRISE_REPORTS_ENABLED = "ENTERPRISE_REPORTS_ENABLED"
	
	CUSTOM_SSL = "CUSTOM_SSL:%{account_id}"

	def newrelic_begin_rescue
	    begin
	      yield
	    rescue Exception => e
	      NewRelic::Agent.notice_error(e)
	      return
	    end 
  	end

	# def increment(key)
	# 	newrelic_begin_rescue { $redis.INCR(key) }
	# end

	# def get_key(key)
	# 	newrelic_begin_rescue { $redis.get(key) }
	# end

	# def remove_key(key)
	# 	newrelic_begin_rescue { $redis.del(key) }
	# end

	# def set_key(key, value, expires = 86400)
	# 	newrelic_begin_rescue do
	# 		$redis.set(key, value)
	# 		$redis.expire(key,expires) if expires
	#   end
	# end

	# def set_expiry(key, expires)
	# 	newrelic_begin_rescue do
	# 		$redis.expire(key, expires)
	# 	end
	# end

	# def get_expiry(key)
	# 	newrelic_begin_rescue { $redis.ttl(key) }
	# end

	# def add_to_set(key, values, expires = 86400)
	# 	newrelic_begin_rescue do
	# 		if values.respond_to?(:each)
	# 			values.each do |val|
	# 				$redis.sadd(key, val)
	# 			end
	# 		else
	# 			$redis.sadd(key, values)
	# 		end
	# 		# $redis.expire(key,expires) if expires
	#   end
	# end

	# def remove_value_from_set(key, value)
	# 	newrelic_begin_rescue { $redis.srem(key, value) }
	# end

	# def set_members(key)
	# 	newrelic_begin_rescue { $redis.smembers(key) }
	# end

	# def list_push(key,values,direction = 'right', expires = 3600)
	# 	newrelic_begin_rescue do
	# 		command = direction == 'right' ? 'rpush' : 'lpush'
	# 		unless values.class == Array
	# 			$redis.send(command, key, values)
	# 		else
	# 			values.each do |val|
	# 				$redis.send(command, key, val)
	# 			end
	# 		end
	# 		$redis.expire(key,expires) if expires
	#   end
	# end

	# def list_pull(key,direction = 'left')
	# 	newrelic_begin_rescue do
	# 		command = direction == 'right' ? 'rpull' : 'lpull'
	# 		$redis.send(command, key)
	#   end
	# end

	# def list_members(key)
	# 	count = 0
 #    tries = 3
 #    begin
	# 		length = $redis.llen(key)
	# 		$redis.lrange(key,0,length - 1)
	#   rescue Exception => e
	#   	NewRelic::Agent.notice_error(e,{:key => key, 
 #        :value => length,
 #        :description => "Redis issue",
 #        :count => count})
 #      if count<tries
 #          count += 1
 #          retry
 #      end
	#   end
	# end

	# def exists(key)
	# 	begin
	# 		$redis.exists(key)
	# 	rescue Exception => e
 #        	NewRelic::Agent.notice_error(e)
 #    	end
	# end

	# def array_of_keys(pattern)
	# 	begin
	# 		$redis.keys(pattern)
	# 	rescue Exception => e
 #        	NewRelic::Agent.notice_error(e)
 #    	end
	# end

	# def publish_to_channel channel, message
	# 	newrelic_begin_rescue do
	#   	return $redis.publish(channel, message)
	#   end
	# end

	# def add_to_hash(hash, key, value, expires = 86400)
	# 	newrelic_begin_rescue do
	# 		$redis.hset(hash, key, value)
	# 		# $redis.expire(hash, expires)
	#   end
	# end

	# def get_hash_value(hash, key)
	# 	newrelic_begin_rescue do
	# 		$redis.hget(hash, key)
	#   end
	# end

end