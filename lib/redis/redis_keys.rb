module Redis::RedisKeys

	HELPDESK_TICKET_FILTERS = "HELPDESK_TICKET_FILTERS:%{account_id}:%{user_id}:%{session_id}"
	EXPORT_TICKET_FIELDS = "EXPORT_TICKET_FIELDS:%{account_id}:%{user_id}:%{session_id}"
	HELPDESK_REPLY_DRAFTS = "HELPDESK_REPLY_DRAFTS:%{account_id}:%{user_id}:%{ticket_id}"
	HELPDESK_GAME_NOTIFICATIONS = "HELPDESK_GAME_NOTIFICATIONS:%{account_id}:%{user_id}"
	HELPDESK_TICKET_ADJACENTS 			= "HELPDESK_TICKET_ADJACENTS:%{account_id}:%{user_id}:%{session_id}"
	HELPDESK_TICKET_ADJACENTS_META	 	= "HELPDESK_TICKET_ADJACENTS_META:%{account_id}:%{user_id}:%{session_id}"
	INTEGRATIONS_JIRA_NOTIFICATION = "INTEGRATIONS_JIRA_NOTIFY:%{account_id}:%{local_integratable_id}:%{remote_integratable_id}:%{comment}"
	INTEGRATIONS_LOGMEIN = "INTEGRATIONS_LOGMEIN:%{account_id}:%{ticket_id}"
	HELPDESK_TICKET_UPDATED_NODE_MSG    = "{\"account_id\":%{account_id},\"ticket_id\":%{ticket_id},\"agent\":\"%{agent_name}\",\"type\":\"%{type}\"}"
	EMPTY_TRASH_TICKETS = "EMPTY_TRASH_TICKETS:%{account_id}"

	EMAIL_TICKET_ID = "EMAIL_TICKET_ID:%{account_id}:%{message_id}"
	PORTAL_PREVIEW = "PORTAL_PREVIEW:%{account_id}:%{user_id}:%{template_id}:%{label}"
	IS_PREVIEW = "IS_PREVIEW:%{account_id}:%{user_id}:%{portal_id}"
	PREVIEW_URL = "PREVIEW_URL:%{account_id}:%{user_id}:%{portal_id}"
	GROUP_AGENT_TICKET_ASSIGNMENT = "GROUP_AGENT_TICKET_ASSIGNMENT:%{account_id}:%{group_id}"
	GROUP_ROUND_ROBIN_AGENTS = "GROUP_ROUND_ROBIN_AGENTS:%{account_id}:%{group_id}"
	ADMIN_ROUND_ROBIN_FILTER = "ADMIN_ROUND_ROBIN_FILTER:%{account_id}:%{user_id}"

	PORTAL_CACHE_ENABLED = "PORTAL_CACHE_ENABLED"
	PORTAL_CACHE_VERSION = "PORTAL_CACHE_VERSION:%{account_id}"
	API_THROTTLER  = "API_THROTTLER:%{host}"
	WEBHOOK_THROTTLER = "WEBHOOK_THROTTLER:%{account_id}"
	#AUTH_REDIRECT_CONFIG = "AUTH_REDIRECT:%{account_id}:%{user_id}:%{provider}:%{auth}"
	SSO_AUTH_REDIRECT_OAUTH = "AUTH_REDIRECT:%{account_id}:%{user_id}:%{provider}:oauth"
	APPS_AUTH_REDIRECT_OAUTH = "AUTH_REDIRECT:%{account_id}:%{provider}:oauth"
	AUTH_REDIRECT_GOOGLE_OPENID = "AUTH_REDIRECT:%{account_id}:google:open_id:%{token}"
	GOOGLE_OAUTH_SSO = "GOOGLE_OAUTH_SSO:%{domain}:%{uid}"

	NEW_QUEUE_MEMBER = "FRESHFONE:NEW_QUEUE_MEMBER:%{account_id}:%{queue_id}"
	AGENT_AVAILABILITY = "FRESHFONE:AGENT_AVAILABILITY:%{account_id}"
	NEW_CALL = "FRESHFONE:NEW_CALL:%{account_id}"
	ACTIVE_CALL = "FRESHFONE_ACTIVE_CALL:%{account_id}:%{call_sid}"
	FRESHFONE_CHANNEL = "FRESHFONE:%{account_id}"
	FRESHFONE_QUEUE_WAIT = "FRESHFONE:QUEUE:%{account_id}:%{call_sid}"
	FRESHFONE_QUEUED_CALLS = "FRESHFONE:CALLS:QUEUE:%{account_id}"
	FRESHFONE_GROUP_QUEUE = "FRESHFONE:GROUP_QUEUE:%{account_id}"
	FRESHFONE_AGENT_QUEUE = "FRESHFONE:AGENT_QUEUE:%{account_id}"
	FRESHFONE_TRANSFER_LOG = "FRESHFONE:TRANSFERS:%{account_id}:%{call_sid}"
	FRESHFONE_CLIENT_CALL = "FRESHFONE:CLIENT_CALLS:%{account_id}"
	FRESHFONE_AGENTS_BATCH = "FRESHFONE:AGENTS_BATCH:%{account_id}:%{call_sid}"
	FRESHFONE_CALLS_BEYOND_THRESHOLD = "FRESHFONE:CALLS_BEYOND_THRESHOLD:%{account_id}"
	FRESHFONE_OUTGOING_CALLS_DEVICE = "FRESHFONE:FRESHFONE_OUTGOING_CALLS_DEVICE:%{account_id}"
	FRESHFONE_DISABLED_WIDGET_ACCOUNTS = "FRESHFONE:DISABLED_WIDGET_ACCOUNTS"
	FRESHFONE_LOW_CREDITS_NOTIFIY = "FRESHFONE:LOW_CREDITS_NOTIFIY"
	FRESHFONE_AUTORECHARGE_TIRGGER = "FRESHFONE:AUTORECHARGE_TRGGER:%{account_id}"
	ADMIN_FRESHFONE_FILTER = "ADMIN_FRESHFONE_FILTER:%{account_id}:%{user_id}"
	
	REPORT_STATS_REGENERATE_KEY = "REPORT_STATS_REGENERATE:%{account_id}" # set of dates for which stats regeneration will happen
	REPORT_STATS_EXPORT_HASH = "REPORT_STATS_EXPORT_HASH:%{account_id}" # last export date, last archive job id and last regen job id
	ENTERPRISE_REPORTS_ENABLED = "ENTERPRISE_REPORTS_ENABLED"
	
	CUSTOM_SSL = "CUSTOM_SSL:%{account_id}"
	SUBSCRIPTIONS_BILLING = "SUBSCRIPTIONS_BILLING:%{account_id}" 
	SEARCH_KEY = "SEARCH_KEY:%{account_id}:%{klass_name}:%{id}"
	ZENDESK_IMPORT_STATUS = "ZENDESK_IMPORT_STATUS:%{account_id}" 
	STREAM_RECENT_SEARCHES = "STREAM_RECENT_SEARCHES:%{account_id}:%{agent_id}"
	STREAM_VOLUME = "STREAM_VOLUME:%{account_id}:%{stream_id}"
	USER_OTP_KEY = "USER_OTP_KEY:%{email}" 
	MOBILE_NOTIFICATION_MESSAGE_CHANNEL = "MOBILE_NOTIFICATION_MESSAGE_CHANNEL_%{channel_id}"
	MOBILE_NOTIFICATION_REGISTRATION_CHANNEL = "MOBILE_NOTIFICATION_REGISTRATION_CHANNEL"

	RIAK_FAILED_TICKET_CREATION = "RIAK:FAILED_TICKET_CREATION"
	RIAK_FAILED_TICKET_DELETION = "RIAK:FAILED_TICKET_DELETION"
	RIAK_FAILED_NOTE_CREATION = "RIAK:FAILED_NOTE_CREATION"
	RIAK_FAILED_NOTE_DELETION = "RIAK:FAILED_NOTE_DELETION"
	
	REPORT_TICKET_FILTERS = "REPORT_TICKET_FILTERS:%{account_id}:%{user_id}:%{session_id}:%{report_type}"
	TICKET_DISPLAY_ID = "TICKET_DISPLAY_ID:%{account_id}"
	DISPLAY_ID_LOCK = "DISPLAY_ID_LOCK:%{account_id}"

	SPAM_MIGRATION = "SPAM_MIGRATION:%{account_id}"
	USER_EMAIL_MIGRATED = "user_email_migrated"
	
	SOLUTION_HIT_TRACKER = "SOLUTION:HITS:%{account_id}:%{article_id}"
	SOLUTION_META_HIT_TRACKER = "SOLUTION_META:HITS:%{account_id}:%{article_meta_id}"
	TOPIC_HIT_TRACKER = "TOPIC:HITS:%{account_id}:%{topic_id}"

	SOLUTION_DRAFTS_SCOPE = "SOLUTION:DRAFTS:%{account_id}:%{user_id}"
	ARTICLE_FEEDBACK_FILTER = "ARTICLE_FEEDBACK_FILTER:%{account_id}:%{user_id}:%{session_id}"

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

	def set_members(key)
		newrelic_begin_rescue { $redis.smembers(key) }
	end

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
