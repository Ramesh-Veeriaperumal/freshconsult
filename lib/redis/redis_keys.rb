module Redis::RedisKeys

	HELPDESK_TICKET_FILTERS = "HELPDESK_TICKET_FILTERS:%{account_id}:%{user_id}:%{session_id}"
	EXPORT_TICKET_FIELDS = "EXPORT_TICKET_FIELDS:%{account_id}:%{user_id}:%{session_id}"
	HELPDESK_REPLY_DRAFTS = "HELPDESK_REPLY_DRAFTS:%{account_id}:%{user_id}:%{ticket_id}"
	HELPDESK_TICKET_ADJACENTS 			= "HELPDESK_TICKET_ADJACENTS:%{account_id}:%{user_id}:%{session_id}"
	HELPDESK_TICKET_ADJACENTS_META	 	= "HELPDESK_TICKET_ADJACENTS_META:%{account_id}:%{user_id}:%{session_id}"
	INTEGRATIONS_JIRA_NOTIFICATION = "INTEGRATIONS_JIRA_NOTIFY:%{account_id}:%{local_integratable_id}:%{remote_integratable_id}:%{comment_id}"
	INTEGRATIONS_LOGMEIN = "INTEGRATIONS_LOGMEIN:%{account_id}:%{ticket_id}"
	INTEGRATIONS_CTI = "INTEGRATIONS_CTI:%{account_id}:%{user_id}"
	INTEGRATIONS_CTI_OLD_PHONE = "INTEGRATIONS_CTI_OLD_PHONE:%{account_id}:%{user_id}"
	HELPDESK_TICKET_UPDATED_NODE_MSG    = "{\"account_id\":%{account_id},\"ticket_id\":%{ticket_id},\"agent\":\"%{agent_name}\",\"type\":\"%{type}\"}"
	EMPTY_TRASH_TICKETS = "EMPTY_TRASH_TICKETS:%{account_id}"
	EMPTY_SPAM_TICKETS = "EMPTY_SPAM_TICKETS:%{account_id}"

	HELPDESK_ARCHIVE_TICKET_FILTERS = "HELPDESK_ARCHIVE_TICKET_FILTERS:%{account_id}:%{user_id}:%{session_id}"
	HELPDESK_ARCHIVE_TICKET_ADJACENTS 			= "HELPDESK_ARCHIVE_TICKET_ADJACENTS:%{account_id}:%{user_id}:%{session_id}"
	HELPDESK_ARCHIVE_TICKET_ADJACENTS_META	 	= "HELPDESK_ARCHIVE_TICKET_ADJACENTS_META:%{account_id}:%{user_id}:%{session_id}"

	EMAIL_TICKET_ID = "EMAIL_TICKET_ID:%{account_id}:%{message_id}"
	PORTAL_PREVIEW = "PORTAL_PREVIEW:%{account_id}:%{user_id}:%{template_id}:%{label}"
	IS_PREVIEW = "IS_PREVIEW:%{account_id}:%{user_id}:%{portal_id}"
	PREVIEW_URL = "PREVIEW_URL:%{account_id}:%{user_id}:%{portal_id}"
	GROUP_ROUND_ROBIN_AGENTS = "GROUP_ROUND_ROBIN_AGENTS:%{account_id}:%{group_id}"
	ADMIN_ROUND_ROBIN_FILTER = "ADMIN_ROUND_ROBIN_FILTER:%{account_id}:%{user_id}"

	PORTAL_CACHE_ENABLED = "PORTAL_CACHE_ENABLED"
	PORTAL_CACHE_VERSION = "PORTAL_CACHE_VERSION:%{account_id}"
	API_THROTTLER  = "API_THROTTLER:%{host}"
	API_THROTTLER_V2 = "API_THROTTLER_V2:%{account_id}"
	ACCOUNT_API_LIMIT = "ACCOUNT_API_LIMIT:%{account_id}"
	DEFAULT_API_LIMIT = "DEFAULT_API_LIMIT"
	TAG_BASED_ARTICLE_SEARCH = "TAG_BASED_ARTICLE_SEARCH"
	PLAN_API_LIMIT = "PLAN_API_LIMIT:%{plan_id}"
	WEBHOOK_THROTTLER = "WEBHOOK_THROTTLER:%{account_id}"
	WEBHOOK_THROTTLER_LIMIT_EXCEEDED = "WEBHOOK_THROTTLER_LIMIT_EXCEEDED:%{account_id}"
	WEBHOOK_ERROR_NOTIFICATION = "WEBHOOK_ERROR_NOTIFICATION:%{account_id}:%{rule_id}"
	
	PREMIUM_GAMIFICATION_ACCOUNT = "PREMIUM_GAMIFICATION_ACCOUNT"
	WEBHOOK_DROP_NOTIFY = "WEBHOOK_DROP_NOTIFY:%{account_id}"
	#AUTH_REDIRECT_CONFIG = "AUTH_REDIRECT:%{account_id}:%{user_id}:%{provider}:%{auth}"
	SSO_AUTH_REDIRECT_OAUTH = "AUTH_REDIRECT:%{account_id}:%{user_id}:%{provider}:oauth"
	APPS_AUTH_REDIRECT_OAUTH = "AUTH_REDIRECT:%{account_id}:%{provider}:oauth"
	APPS_USER_CRED_REDIRECT_OAUTH = "AUTH_USER_REDIRECT:%{account_id}:%{provider}:%{user_id}:oauth"
	GADGET_VIEWERID_AUTH = "AUTH_REDIRECT:%{account_id}:google:viewer_id:%{token}"
	GOOGLE_OAUTH_SSO = "GOOGLE_OAUTH_SSO:%{random_key}"
	GOOGLE_MARKETPLACE_SIGNUP = "GOOGLE_MARKETPLACE_SIGNUP:%{email}"

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
	FRESHFONE_CALL = "FRESHFONE:CALL:%{account_id}:%{child_sid}"
	FRESHFONE_USER_AGENT = "FRESHFONE:USER_AGENT:%{account_id}:%{user_id}:%{warm_transfer_id}"
	ADMIN_FRESHFONE_FILTER = "ADMIN_FRESHFONE_FILTER:%{account_id}:%{user_id}"
	ADMIN_FRESHFONE_REPORTS_FILTER = "ADMIN_FRESHFONE_REPORTS_FILTER:%{account_id}:%{user_id}"
	ADMIN_CALLS_FILTER = "ADMIN_CALLS_FILTER:%{account_id}:%{user_id}"
	FRESHFONE_PINGED_AGENTS = "FRESHFONE:PINGED_AGENTS:%{account_id}:%{call_id}"
	FRESHFONE_CALL_NOTABLE = "FRESHFONE:CALL_NOTABLE:%{account_id}:%{call_id}"
	FRESHFONE_ACTIVATION_REQUEST = "FRESHFONE:ACTIVATION_REQUEST:%{account_id}"
	INVALID_FORWARD_INPUT_COUNT = "FRESHFONE:INVALID_FORWARD_INPUT_COUNT:%{account_id}:%{call_id}"
	FACEBOOK_APP_RATE_LIMIT = "FACEBOOK_APP_RATE_LIMIT"
	FACEBOOK_LIKES          = "FACEBOOK_LIKES"
	FACEBOOK_USER_RATE_LIMIT = "FACEBOOK_USER_RATE_LIMIT:%{page_id}"
	FACEBOOK_PAGE_RATE_LIMIT = "FACEBOOK_PAGE_RATE_LIMIT:%{account_id}:%{page_id}"
	FACEBOOK_API_HIT_COUNT  = "FACEBOOK_API_HIT_COUNT:%{page_id}"
	FRESHFONE_CALL_QUALITY_METRICS = "FRESHFONE:CALL_QUALITY_METRICS:%{account_id}:%{dial_call_sid}"
	FRESHFONE_SIMULTANEOUS_ACCEPT = "FRESHFONE:SIMULTANEOUS_ACCEPT:%{account_id}:%{call_id}"
	
	FRESHFONE_SUPERVISOR_LEG = "FRESHFONE:SUPERVISOR_LEG:%{account_id}:%{user_id}:%{call_sid}"
	FRESHFONE_PREVIEW_IVR = "FRESHFONE:PREVIEW_IVR:%{account_id}:%{call_sid}"
	REPORT_STATS_REGENERATE_KEY = "REPORT_STATS_REGENERATE:%{account_id}" # set of dates for which stats regeneration will happen
	REPORT_STATS_EXPORT_HASH = "REPORT_STATS_EXPORT_HASH:%{account_id}" # last export date, last archive job id and last regen job id
	ENTERPRISE_REPORTS_ENABLED = "ENTERPRISE_REPORTS_ENABLED"
	CLASSIC_REPORTS_ENABLED = "CLASSIC_REPORTS_ENABLED"
	OLD_REPORTS_ENABLED = "OLD_REPORTS_ENABLED"

	CUSTOM_SSL = "CUSTOM_SSL:%{account_id}"
	SUBSCRIPTIONS_BILLING = "SUBSCRIPTIONS_BILLING:%{account_id}"
	SEARCH_KEY = "SEARCH_KEY:%{account_id}:%{klass_name}:%{id}"
	ZENDESK_IMPORT_STATUS = "ZENDESK_IMPORT_STATUS:%{account_id}"
	ZENDESK_IMPORT_CUSTOM_DROP_DOWN = "ZENDESK_IMPORT_CUSTOM_DROP_DOWN_%{account_id}"
	STREAM_RECENT_SEARCHES = "STREAM_RECENT_SEARCHES:%{account_id}:%{agent_id}"
	STREAM_VOLUME = "STREAM_VOLUME:%{account_id}:%{stream_id}"
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
	SPAM_EMAIL_ACCOUNTS  = "SPAM_EMAIL_ACCOUNTS"
	PREMIUM_EMAIL_ACCOUNTS = "PREMIUM_EMAIL_ACCOUNTS"
	USER_EMAIL_MIGRATED = "user_email_migrated"

	SOLUTION_HIT_TRACKER = "SOLUTION:HITS:%{account_id}:%{article_id}"
	SOLUTION_META_HIT_TRACKER = "SOLUTION_META:HITS:%{account_id}:%{article_meta_id}"
	TOPIC_HIT_TRACKER = "TOPIC:HITS:%{account_id}:%{topic_id}"
	PROCESS_EMAIL_PROGRESS = "PROCESS_EMAIL:%{account_id}:%{unique_key}"
	
	SELECT_ALL = "SELECT_ALL:%{account_id}"

	SOLUTION_DRAFTS_SCOPE = "SOLUTION:DRAFTS:%{account_id}:%{user_id}"
	ARTICLE_FEEDBACK_FILTER = "ARTICLE_FEEDBACK_FILTER:%{account_id}:%{user_id}:%{session_id}"
	#These are redis set keys used for temporary feature checks.
	COMPOSE_EMAIL_ENABLED = "COMPOSE_EMAIL_ENABLED"
	BI_REPORTS_UI_ENABLED = "BI_REPORTS_UI"
	BI_REPORTS_REAL_TIME_PDF = "BI_REPORTS_REAL_TIME_PDF"
	BI_REPORTS_ATTACHMENT_VIA_S3 = "BI_REPORTS_ATTACHMENT_VIA_S3"
	BI_REPORTS_MAIL_ATTACHMENT_LIMIT_IN_BYTES = "BI_REPORTS_MAIL_ATTACHMENT_LIMIT_IN_BYTES"
	BI_REPORTS_INTERNAL_CSV_EXPORT = "BI_REPORTS_INTERNAL_CSV_EXPORT"
	PREMIUM_TICKET_EXPORT = "PREMIUM_TICKET_EXPORT"
	LONG_RUNNING_TICKET_EXPORT = "LONG_RUNNING_TICKET_EXPORT"
	DASHBOARD_DISABLED = "DASHBOARD_DISABLED"
	RESTRICTED_COMPOSE = "RESTRICTED_COMPOSE"
	SLAVE_QUERIES = "SLAVE_QUERIES"
	VALIDATE_REQUIRED_TICKET_FIELDS = "VALIDATE_REQUIRED_TICKET_FIELDS"
	PLUGS_IN_NEW_TICKET = "PLUGS_IN_NEW_TICKET"

	UPDATE_PASSWORD_EXPIRY = "UPDATE_PASSWORD_EXPIRY:%{account_id}:%{user_type}"

	EBAY_APP_THRESHOLD_COUNT = "EBAY:APP:THRESHOLD:%{date}:%{app_id}"
	EBAY_ACCOUNT_THRESHOLD_COUNT = "EBAY:ACCOUNT:THRESHOLD:%{date}:%{account_id}:%{ebay_account_id}"

	CARD_FAILURE_COUNT = "CREDIT_CARD_FAILURE_COUNT:%{account_id}"
	
	EMAIL_CONFIG_BLACKLISTED_DOMAINS = "email_config_blacklisted_domains"

  EMAIL_TEMPLATE_SPAM_DOMAINS = "EMAIL_TEMPLATE_SPAM_DOMAINS"
  SPAM_USER_EMAIL_DOMAINS = "SPAM_USER_EMAIL_DOMAINS"
  SPAM_NOTIFICATION_WHITELISTED_DOMAINS_EXPIRY = "SPAM_NOTIFICATION_WHITELISTED_DOMAINS:%{account_id}"

  DISPATCHER_SIDEKIQ_ENABLED = "DISPATCHER_SIDEKIQ_ENABLED"
  ACCOUNT_EXPORT_SIDEKIQ_ENABLED = "ACCOUNT_EXPORT_SIDEKIQ_ENABLED"
  TICKET_EXPORT_SIDEKIQ_ENABLED = "TICKET_EXPORT_SIDEKIQ_ENABLED"
  
  GAMIFICATION_QUEST_COOLDOWN = "GAMIFICATION:QUEST:%{account_id}:%{user_id}"
  GAMIFICATION_AGENTS_LEADERBOARD = "GAMIFICATION_AGENTS_LEADERBOARD:%{account_id}:%{category}:%{month}"
  GAMIFICATION_GROUPS_LEADERBOARD = "GAMIFICATION_GROUPS_LEADERBOARD:%{account_id}:%{category}:%{month}"
  GAMIFICATION_GROUP_AGENTS_LEADERBOARD = "GAMIFICATION_GROUP_AGENTS_LEADERBOARD:%{account_id}:%{category}:%{month}:%{group_id}"

  MULTI_FILE_ATTACHMENT = "MULTI_FILE_ATTACHMENT:%{date}"
  #Dashboard v2 caching keys starts
  ADMIN_WIDGET_CACHE_SET =  "ADMIN_WIDGET_CACHE_SET:%{account_id}"
  GROUP_WIDGET_CACHE_SET =  "GROUP_WIDGET_CACHE_SET:%{account_id}"
  ADMIN_WIDGET_CACHE_GET =  "ADMIN_WIDGET_CACHE_GET:%{account_id}"
  GROUP_WIDGET_CACHE_GET =  "GROUP_WIDGET_CACHE_GET:%{account_id}"
  #Dashboard v2 caching keys ends

  PERSISTENT_RECENT_SEARCHES = "PERSISTENT_RECENT_SEARCHES:%{account_id}:%{user_id}"
  PERSISTENT_RECENT_TICKETS = "PERSISTENT_RECENT_TICKETS:%{account_id}:%{user_id}"

  #update tickets sla - move from delayed job to sidekiq starts
  SLA_ON_STATUS_CHANGE = "SLA_ON_STATUS_CHANGE"
  #update tickets sla - move from delayed job to sidekiq ends

	# List of languages used by agents in an account
  AGENT_LANGUAGE_LIST 	 = "AGENT_LANGUAGE_LIST:%{account_id}"
  # List of languges used by customers in an account
  CUSTOMER_LANGUAGE_LIST = "CUSTOMER_LANGUAGE_LIST:%{account_id}"

  BLACKLISTED_SPAM_ACCOUNTS = "BLACKLISTED_SPAM_ACCOUNTS"
  BLACKLISTED_SPAM_DOMAINS = "BLACKLISTED_SPAM_DOMAINS"

  SPAM_EMAIL_EXACT_REGEX_KEY = "SPAM_EMAIL_EXACT_REGEX"
  SPAM_EMAIL_APPRX_REGEX_KEY = "SPAM_EMAIL_APPRX_REGEX"
  PROCESSING_FAILED_HELPKIT_FEEDS = "PROCESSING_FAILED_HELPKIT_FEEDS"

  ROUND_ROBIN_CAPPING = "ROUND_ROBIN_CAPPING:%{account_id}:%{group_id}"
  ROUND_ROBIN_CAPPING_PERMIT = "ROUND_ROBIN_CAPPING_PERMIT:%{account_id}:%{group_id}"
  ROUND_ROBIN_AGENT_CAPPING = "ROUND_ROBIN_AGENT_CAPPING:%{account_id}:%{group_id}:%{user_id}"
  RR_CAPPING_TICKETS_QUEUE = "RR_CAPPING_TICKETS_QUEUE:%{account_id}:%{group_id}"
  RR_CAPPING_TEMP_TICKETS_QUEUE = "RR_CAPPING_TEMP_TICKETS_QUEUE:%{account_id}:%{group_id}"

  RR_CAPPING_TICKETS_DEFAULT_SORTED_SET = "RR_CAPPING_TICKETS_DEFAULT_SORTED_SET:%{account_id}:%{group_id}"

  OUTGOING_COUNT_PER_HALF_HOUR = "OUTGOING_COUNT_PER_HALF_HOUR:%{account_id}"
  SPAM_ACCOUNT_ID_THRESHOLD = "SPAM_ACCOUNT_ID_THRESHOLD"
  SPAM_OUTGOING_EMAILS_THRESHOLD = "SPAM_OUTGOING_EMAILS_THRESHOLD"
  OUTBOUND_EMAIL_COUNT_PER_DAY = "OUTBOUND_EMAIL_COUNT_PER_DAY:%{account_id}"
  TRIAL_ACCOUNT_MAX_TO_CC_THRESHOLD = "TRIAL_ACCOUNT_MAX_TO_CC_THRESHOLD"

  SPAM_WHITELISTED_ACCOUNTS = "SPAM_WHITELISTED_ACCOUNTS"
  SPAM_ACCOUNT_TIME_LIMIT = "SPAM_ACCOUNT_TIME_LIMIT"
  JWT_SSO_JTI = "JTI_%{account_id}_%{jti}"

  #Key check for read/write canned and scenario automations to count esv2
  COUNT_ESV2_WRITE_ENABLED 	= "COUNT_ESV2_WRITE_ENABLED"
  COUNT_ESV2_READ_ENABLED 	= "COUNT_ESV2_READ_ENABLED"

  MAILGUN_EVENT_LAST_SYNC = "MAILGUN_EVENT_LAST_SYNC:%{domain}"

  
  # keys for switching the email traffic to mailgun
  TRIAL_MAILGUN_TRAFFIC_PERCENTAGE = "TRIAL_MAILGUN_TRAFFIC_PERCENTAGE"
  ACTIVE_MAILGUN_TRAFFIC_PERCENTAGE = "ACTIVE_MAILGUN_TRAFFIC_PERCENTAGE"
  PREMIUM_MAILGUN_TRAFFIC_PERCENTAGE = "PREMIUM_MAILGUN_TRAFFIC_PERCENTAGE"
  FREE_MAILGUN_TRAFFIC_PERCENTAGE = "FREE_MAILGUN_TRAFFIC_PERCENTAGE"
  DEFAULT_MAILGUN_TRAFFIC_PERCENTAGE = "DEFAULT_MAILGUN_TRAFFIC_PERCENTAGE"
  SPAM_MAILGUN_TRAFFIC_PERCENTAGE = "SPAM_MAILGUN_TRAFFIC_PERCENTAGE"


  INTERNAL_TOOLS_IP = "INTERNAL_TOOLS_IP"

  #Following are the dead keys. Need to remove them from code and any references
  GROUP_AGENT_TICKET_ASSIGNMENT = "GROUP_AGENT_TICKET_ASSIGNMENT:%{account_id}:%{group_id}"
  HELPDESK_GAME_NOTIFICATIONS = "HELPDESK_GAME_NOTIFICATIONS:%{account_id}:%{user_id}"
  DASHBOARD_TABLE_FILTER_KEY = "DASHBOARD_TABLE_FILTER_KEY:%{account_id}:%{user_id}"
  USER_OTP_KEY = "USER_OTP_KEY:%{email}" #deadkey
  #End of dead keys

  #NOTE::
  #When you add a new redis key, please add the constant to the specific set of below array based on what type of key it is.
  #If its a new type, please define a new type and add it in delete_account.rb. The below keys are removed before account
  #destroy during account cancellation.
  ACCOUNT_RELATED_KEYS = [
        EMPTY_TRASH_TICKETS, EMPTY_SPAM_TICKETS, PORTAL_CACHE_VERSION, API_THROTTLER_V2, ACCOUNT_API_LIMIT, WEBHOOK_THROTTLER, 
        WEBHOOK_THROTTLER_LIMIT_EXCEEDED, WEBHOOK_DROP_NOTIFY, AGENT_AVAILABILITY, NEW_CALL, FRESHFONE_CHANNEL, 
        FRESHFONE_QUEUED_CALLS, FRESHFONE_GROUP_QUEUE, FRESHFONE_AGENT_QUEUE, FRESHFONE_CLIENT_CALL, FRESHFONE_CALLS_BEYOND_THRESHOLD, 
        FRESHFONE_OUTGOING_CALLS_DEVICE, FRESHFONE_AUTORECHARGE_TIRGGER, FRESHFONE_ACTIVATION_REQUEST, REPORT_STATS_REGENERATE_KEY, 
        REPORT_STATS_EXPORT_HASH, CUSTOM_SSL, SUBSCRIPTIONS_BILLING, ZENDESK_IMPORT_STATUS, ZENDESK_IMPORT_CUSTOM_DROP_DOWN, 
        SPAM_MIGRATION, ADMIN_WIDGET_CACHE_SET, GROUP_WIDGET_CACHE_SET, ADMIN_WIDGET_CACHE_GET, 
        GROUP_WIDGET_CACHE_GET, AGENT_LANGUAGE_LIST, CUSTOMER_LANGUAGE_LIST, OUTGOING_COUNT_PER_HALF_HOUR, OUTBOUND_EMAIL_COUNT_PER_DAY
      ]

  DISPLAY_ID_KEYS = [TICKET_DISPLAY_ID]


  ACCOUNT_GROUP_KEYS = [
  			GROUP_ROUND_ROBIN_AGENTS, ROUND_ROBIN_CAPPING, ROUND_ROBIN_CAPPING_PERMIT, RR_CAPPING_TICKETS_QUEUE, 
          	RR_CAPPING_TEMP_TICKETS_QUEUE, RR_CAPPING_TICKETS_DEFAULT_SORTED_SET
          ]

  ACCOUNT_GROUP_USER_KEYS = [ROUND_ROBIN_AGENT_CAPPING]


  ACCOUNT_USER_KEYS = [
  		ADMIN_ROUND_ROBIN_FILTER,ADMIN_FRESHFONE_FILTER,ADMIN_FRESHFONE_REPORTS_FILTER,ADMIN_CALLS_FILTER,
        SOLUTION_DRAFTS_SCOPE,GAMIFICATION_QUEST_COOLDOWN,PERSISTENT_RECENT_TICKETS
    ]

  ACCOUNT_AGENT_ID_KEYS = [STREAM_RECENT_SEARCHES]

  ACCOUNT_HOST_KEYS = [API_THROTTLER]

  ACCOUNT_ARTICLE_KEYS = [SOLUTION_HIT_TRACKER]

  ACCOUNT_ARTICLE_META_KEYS = [SOLUTION_META_HIT_TRACKER]

  ACCOUNT_TOPIC_KEYS = [TOPIC_HIT_TRACKER]



  MARKETPLACE_APP_TICKET_DETAILS = "MARKETPLACE_APP_TICKET_DETAILS:%{account_id}"
  AUTOMATION_TICKET_PARAMS = "AUTOMATION_TICKET_PARAMS:%{account_id}:%{ticket_id}"

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