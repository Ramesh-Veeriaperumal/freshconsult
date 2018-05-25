module Redis::RedisKeys

  include Redis::PrivateApiKeys

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
  MIGRATED_EMAIL_TICKET_ID = "MIGRATED_EMAIL_TICKET_ID:%{account_id}:%{email_config_id}:%{message_id}"
  PORTAL_PREVIEW = "PORTAL_PREVIEW:%{account_id}:%{user_id}:%{template_id}:%{label}"
  IS_PREVIEW = "IS_PREVIEW:%{account_id}:%{user_id}:%{portal_id}"
  PREVIEW_URL = "PREVIEW_URL:%{account_id}:%{user_id}:%{portal_id}"
  GROUP_ROUND_ROBIN_AGENTS = "GROUP_ROUND_ROBIN_AGENTS:%{account_id}:%{group_id}"
  ADMIN_ROUND_ROBIN_FILTER = "ADMIN_ROUND_ROBIN_FILTER:%{account_id}:%{user_id}"

  ACCOUNT_ONBOARDING_PENDING = "ACCOUNT_ONBOARDING_PENDING:%{account_id}"

  PORTAL_CACHE_ENABLED = "PORTAL_CACHE_ENABLED"
  PORTAL_CACHE_VERSION = "PORTAL_CACHE_VERSION:%{account_id}"
  SOLUTIONS_PORTAL_CACHE_VERSION = "SOLUTIONS_PORTAL_CACHE_VERSION:%{account_id}"
  API_THROTTLER  = "API_THROTTLER:%{host}"
  API_THROTTLER_V2 = "API_THROTTLER_V2:%{account_id}"
  ACCOUNT_API_LIMIT = "ACCOUNT_API_LIMIT:%{account_id}"
  DEFAULT_API_LIMIT = "DEFAULT_API_LIMIT"
  PRIVATE_API_THROTTLER = 'PRIVATE_API_THROTTLER:%{account_id}'.freeze
  ACCOUNT_PRIVATE_API_LIMIT = 'ACCOUNT_PRIVATE_API_LIMIT:%{account_id}'.freeze
  DEFAULT_PRIVATE_API_LIMIT = 'DEFAULT_PRIVATE_API_LIMIT'.freeze
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
  MICROSOFT_OFFICE365_KEYS = "MICROSOFT_OFFICE365_KEYS"

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
  FRESHFONE_PINGED_RESPONSE = "FRESHFONE:PINGED_RESPONSE:%{account_id}:%{call_id}"
  FRESHFONE_AGENT_INFO = "FRESHFONE:AGENT_INFO:%{account_id}:%{call_id}"
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
  FRESHFONE_VOICEMAIL_CALL = "FRESHFONE:VOICEMAIL_CALL:%{account_id}:%{call_id}"
  DISABLE_DESKTOP_NOTIFICATIONS = "DESKTOP_NOTIFICATION_DISABLE:%{account_id}:%{user_id}"

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
  MESSAGE_PROCESS_STATE  = "MESSAGE_PROCESS_STATE:%{uid}"
  MESSAGE_RETRY_STATE = "MESSAGE_RETRY_STATE:%{uid}"
  PROCESS_EMAIL_PROGRESS = "PROCESS_EMAIL:%{account_id}:%{unique_key}"
  PROCESSED_TICKET_DATA = "PROCESSED_TICKET_DATA:%{uid}"

  SELECT_ALL = "SELECT_ALL:%{account_id}"

  SITEMAP_OUTDATED = "SITEMAP_OUTDATED:%{account_id}"

  SOLUTION_DRAFTS_SCOPE = "SOLUTION:DRAFTS:%{account_id}:%{user_id}"
  ARTICLE_FEEDBACK_FILTER = "ARTICLE_FEEDBACK_FILTER:%{account_id}:%{user_id}:%{session_id}"
  #These are redis set keys used for temporary feature checks.
  COMPOSE_EMAIL_ENABLED = "COMPOSE_EMAIL_ENABLED"
  BI_REPORTS_UI_ENABLED = "BI_REPORTS_UI"
  BI_REPORTS_REAL_TIME_PDF = "BI_REPORTS_REAL_TIME_PDF"
  BI_REPORTS_ATTACHMENT_VIA_S3 = "BI_REPORTS_ATTACHMENT_VIA_S3"
  BI_REPORTS_MAIL_ATTACHMENT_LIMIT_IN_BYTES = "BI_REPORTS_MAIL_ATTACHMENT_LIMIT_IN_BYTES"
  BI_REPORTS_INTERNAL_CSV_EXPORT = "BI_REPORTS_INTERNAL_CSV_EXPORT"
  DASHBOARD_DISABLED = "DASHBOARD_DISABLED"
  RESTRICTED_COMPOSE = "RESTRICTED_COMPOSE"
  SLAVE_QUERIES = "SLAVE_QUERIES"
  MASTER_QUERIES = "MASTER_QUERIES"
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

  #Timestamp key for Redis AOF reference.
  TIMESTAMP_REFERENCE = "TIMESTAMP_REFERENCE"

  PERSISTENT_RECENT_SEARCHES = "PERSISTENT_RECENT_SEARCHES:%{account_id}:%{user_id}"
  PERSISTENT_RECENT_TICKETS = "PERSISTENT_RECENT_TICKETS:%{account_id}:%{user_id}"

  # List of languages used by agents in an account
  AGENT_LANGUAGE_LIST 	 = "AGENT_LANGUAGE_LIST:%{account_id}"
  # List of languges used by customers in an account
  CUSTOMER_LANGUAGE_LIST = "CUSTOMER_LANGUAGE_LIST:%{account_id}"

  # BLACKLISTED_SPAM_ACCOUNTS = "BLACKLISTED_SPAM_ACCOUNTS"
  SPAM_REPORTS_COUNT = "SPAM_REPORTS_COUNT:%{account_id}"
  MAX_SPAM_REPORTS_ALLOWED = "MAX_SPAM_REPORTS_ALLOWED:%{state}"
  BLACKLISTED_SPAM_DOMAINS = "BLACKLISTED_SPAM_DOMAINS"

  SPAM_EMAIL_EXACT_REGEX_KEY = "SPAM_EMAIL_EXACT_REGEX"
  SPAM_EMAIL_APPRX_REGEX_KEY = "SPAM_EMAIL_APPRX_REGEX"
  PROCESSING_FAILED_HELPKIT_FEEDS = "PROCESSING_FAILED_HELPKIT_FEEDS"
  PROCESSING_FAILED_CENTRAL_FEEDS = "PROCESSING_FAILED_CENTRAL_FEEDS"

  ROUND_ROBIN_CAPPING = "ROUND_ROBIN_CAPPING:%{account_id}:%{group_id}"
  ROUND_ROBIN_CAPPING_PERMIT = "ROUND_ROBIN_CAPPING_PERMIT:%{account_id}:%{group_id}"
  ROUND_ROBIN_AGENT_CAPPING = "ROUND_ROBIN_AGENT_CAPPING:%{account_id}:%{group_id}:%{user_id}"
  RR_CAPPING_TICKETS_QUEUE = "RR_CAPPING_TICKETS_QUEUE:%{account_id}:%{group_id}"
  RR_CAPPING_TEMP_TICKETS_QUEUE = "RR_CAPPING_TEMP_TICKETS_QUEUE:%{account_id}:%{group_id}"

  RR_CAPPING_TICKETS_DEFAULT_SORTED_SET = "RR_CAPPING_TICKETS_DEFAULT_SORTED_SET:%{account_id}:%{group_id}"

  #skill based round robin keys
  SKILL_BASED_TICKETS_SORTED_SET = "SKILL_BASED_TICKETS_SORTED_SET:%{account_id}:%{group_id}:%{skill_id}"
  SKILL_BASED_TICKETS_LOCK_KEY = "SKILL_BASED_TICKETS_LOCK_KEY:%{account_id}:%{ticket_id}"

  SKILL_BASED_USERS_SORTED_SET = "SKILL_BASED_USERS_SORTED_SET:%{account_id}:%{group_id}:%{skill_id}"
  SKILL_BASED_USERS_LOCK_KEY = "SKILL_BASED_USERS_LOCK_KEY:%{account_id}:%{group_id}:%{user_id}"
  #skill based round robin keys - end

  OUTGOING_COUNT_PER_HALF_HOUR = "OUTGOING_COUNT_PER_HALF_HOUR:%{account_id}"
  SPAM_ACCOUNT_ID_THRESHOLD = "SPAM_ACCOUNT_ID_THRESHOLD"
  SPAM_OUTGOING_EMAILS_THRESHOLD = "SPAM_OUTGOING_EMAILS_THRESHOLD"
  OUTBOUND_EMAIL_COUNT_PER_DAY = "OUTBOUND_EMAIL_COUNT_PER_DAY:%{account_id}"
  TRIAL_ACCOUNT_MAX_TO_CC_THRESHOLD = "TRIAL_ACCOUNT_MAX_TO_CC_THRESHOLD"
  FREE_ACCOUNT_30_DAYS_THRESHOLD = "FREE_ACCOUNT_30_DAYS_THRESHOLD"
  FREE_ACCOUNT_OUTBOUND_THRESHOLD = "FREE_ACCOUNT_OUTBOUND_THRESHOLD"
  SPAM_BLACKLISTED_RULES = "SPAM_BLACKLISTED_RULES"
  EMAIL_THRESHOLD_CROSSED_TICKETS = "EMAIL_THRESHOLD_CROSSED_TICKETS:%{account_id}"

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


  SIGNUP_RESTRICTED_DOMAINS = "SIGNUP_RESTRICTED_DOMAINS"

  SIGNUP_RESTRICTED_EMAIL_DOMAINS = "SIGNUP_RESTRICTED_EMAIL_DOMAINS"

  # Email sender config redis key
  EMAIL_SENDER_CONFIG = "EMAIL_SENDER_CONFIG:%{account_id}:%{email_type}"

  # Key to hold the "From" of various language. This helps in identifying the original sender while agent forward
  AGENT_FORWARD_FROM_REGEX = "AGENT_FORWARD_FROM_REGEX"

  # Key to hold the "To" of various language. This helps in identifying the original recipient while agent forward
  AGENT_FORWARD_TO_REGEX = "AGENT_FORWARD_TO_REGEX"

  # key for enabling fd email service to all the account

  ROUTE_NOTIFICATIONS_VIA_EMAIL_SERVICE = "ROUTE_NOTIFICATIONS_VIA_EMAIL_SERVICE"

  ROUTE_EMAILS_VIA_FD_SMTP_SERVICE = "ROUTE_EMAILS_VIA_FD_SMTP_SERVICE"
  INTERNAL_TOOLS_IP = "INTERNAL_TOOLS_IP"
  ACCOUNT_SETUP = "ACCOUNT_SETUP:%{account_id}"

  NEW_SIGNUP_ENABLED = "NEW_SIGNUP_ENABLED"

  META_DATA_TIMESTAMP = "META_DATA_TIMESTAMP"

  ACCOUNT_ADMIN_ACTIVATION_JOB_ID = "ACCOUNT_ADMIN_ACTIVATION_JOB_ID:%{account_id}"

  # Languages available for falcon signup
  FALCON_ENABLED_LANGUAGES = "FALCON_ENABLED_LANGUAGES"
  # Search Service Keys
  SEARCH_SERVICE_SIGNUP = "SEARCH_SERVICE_SIGNUP"

  #Following are the dead keys. Need to remove them from code and any references
  GROUP_AGENT_TICKET_ASSIGNMENT = "GROUP_AGENT_TICKET_ASSIGNMENT:%{account_id}:%{group_id}"
  HELPDESK_GAME_NOTIFICATIONS = "HELPDESK_GAME_NOTIFICATIONS:%{account_id}:%{user_id}"
  DASHBOARD_TABLE_FILTER_KEY = "DASHBOARD_TABLE_FILTER_KEY:%{account_id}:%{user_id}"
  DASHBOARD_FEATURE_ENABLED_KEY = "DASHBOARD_FEATURE_ENABLED_KEY"
  USER_OTP_KEY = "USER_OTP_KEY:%{email}" #deadkey
  #End of dead keys

  #NOTE::
  #When you add a new redis key, please add the constant to the specific set of below array based on what type of key it is.
  #If its a new type, please define a new type and add it in delete_account.rb. The below keys are removed before account
  #destroy during account cancellation.

  DASHBOARD_INDEX = "DASHBOARD_INDEX:%{account_id}"
  ACCOUNT_RELATED_KEYS = [
    EMPTY_TRASH_TICKETS, EMPTY_SPAM_TICKETS, PORTAL_CACHE_VERSION, API_THROTTLER_V2, ACCOUNT_API_LIMIT, WEBHOOK_THROTTLER,
    WEBHOOK_THROTTLER_LIMIT_EXCEEDED, WEBHOOK_DROP_NOTIFY, AGENT_AVAILABILITY, NEW_CALL, FRESHFONE_CHANNEL,
    FRESHFONE_QUEUED_CALLS, FRESHFONE_GROUP_QUEUE, FRESHFONE_AGENT_QUEUE, FRESHFONE_CLIENT_CALL, FRESHFONE_CALLS_BEYOND_THRESHOLD,
    FRESHFONE_OUTGOING_CALLS_DEVICE, FRESHFONE_AUTORECHARGE_TIRGGER, FRESHFONE_ACTIVATION_REQUEST, REPORT_STATS_REGENERATE_KEY,
    REPORT_STATS_EXPORT_HASH, CUSTOM_SSL, SUBSCRIPTIONS_BILLING, ZENDESK_IMPORT_STATUS, ZENDESK_IMPORT_CUSTOM_DROP_DOWN,
    SPAM_MIGRATION, ADMIN_WIDGET_CACHE_SET, GROUP_WIDGET_CACHE_SET, ADMIN_WIDGET_CACHE_GET,
    GROUP_WIDGET_CACHE_GET, AGENT_LANGUAGE_LIST, CUSTOMER_LANGUAGE_LIST, OUTGOING_COUNT_PER_HALF_HOUR, OUTBOUND_EMAIL_COUNT_PER_DAY, DASHBOARD_INDEX
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

  ACCOUNT_SIGN_UP_PARAMS = "ACCOUNT_SIGN_UP_PARAMS:%{account_id}"

  EHAWK_SPAM_COMMUNITY_REGEX_KEY = "EHAWK_SPAM_COMMUNITY_REGEX"
  EHAWK_SPAM_EMAIL_REGEX_KEY = "EHAWK_SPAM_EMAIL_REGEX"
  EHAWK_IP_BLACKLISTED_REGEX_KEY = "EHAWK_IP_BLACKLISTED_REGEX"
  EHAWK_SPAM_COUNTRY_REGEX_KEY = "EHAWK_SPAM_COUNTRY_REGEX"
  EHAWK_SPAM_GEOLOCATION_REGEX_KEY = "EHAWK_SPAM_GEOLOCATION_REGEX"
  EHAWK_IP_DISTANCE_VELOCITY_LIMIT_KEY = "EHAWK_IP_DISTANCE_VELOCITY_LIMIT"
  EHAWK_WHITELISTED_IP = "EHAWK_WHITELISTED_IP"
  EHAWK_WHITELISTED_EMAIL = "EHAWK_WHITELISTED_EMAIL"
  EHAWK_BLACKLISTED_IP = "EHAWK_BLACKLISTED_IP"
  EHAWK_BLACKLISTED_EMAIL = "EHAWK_BLACKLISTED_EMAIL"

  MARKETPLACE_APP_TICKET_DETAILS = "MARKETPLACE_APP_TICKET_DETAILS:%{account_id}"
  AUTOMATION_TICKET_PARAMS = "AUTOMATION_TICKET_PARAMS:%{account_id}:%{ticket_id}"
  ARTICLE_SPAM_REGEX = "ARTICLE_SPAM_REGEX"
  FORUM_POST_SPAM_REGEX = "FORUM_POST_SPAM_REGEX"
  PHONE_NUMBER_SPAM_REGEX = "PHONE_NUMBER_SPAM_REGEX"
  CONTENT_SPAM_CHAR_REGEX = "CONTENT_SPAM_CHAR_REGEX"

  CROSS_DOMAIN_API_GET_DISABLED = "CROSS_DOMAIN_API_GET_DISABLED"

  DKIM_CATEGORY_KEY = "DKIM_CATEGORY_CHANGER"
  DKIM_VERIFICATION_KEY = "DKIM_VERIFICATION:%{account_id}:%{email_domain_id}"
  DKIM_CONFIGURATION_IN_PROGRESS_KEY = "DKIM_CONFIGURATION_IN_PROGRESS"

  WHITELISTED_DOMAINS_KEY = "WHITELISTED_DOMAINS_KEY"

  BACKGROUND_FIXTURES_ENABLED = "BACKGROUND_FIXTURES_ENABLED"
  BACKGROUND_FIXTURES_STATUS = "BACKGROUND_FIXTURES_STATUS:%{account_id}"
  ACTIVE_SUSPENDED = "ACTIVE_SUSPENDED:%{account_id}"
  CLEARBIT_NOTIFICATION = "CLEARBIT_NOTIFICATION"

  CLAMAV_CONNECTION_ERROR_TIMEOUT = "CLAMAV_CONNECTION_ERROR_TIMEOUT"

  CLOSE_VALIDATION = "CLOSE_VALIDATION"
  CUSTOM_CATEGORY_NOTIFICATIONS = "CUSTOM_CATEGORY_NOTIFICATIONS"
  SPAM_FILTERED_NOTIFICATIONS = "SPAM_FILTERED_NOTIFICATIONS"
  HAPROXY_IP_BLACKLIST_KEY = "HAPROXY_IP_BLACKLIST_KEY"
  HAPROXY_DOMAIN_BLACKLIST_KEY = "HAPROXY_DOMAIN_BLACKLIST_KEY"
  HAPROXY_IP_BLACKLIST_CHANNEL = "HAPROXY_IP_BLACKLIST_CHANNEL"

  FACEBOOK_PREMIUM_ACCOUNTS = "FACEBOOK_PREMIUM_ACCOUNTS"
  TWITTER_PREMIUM_ACCOUNTS = "TWITTER_PREMIUM_ACCOUNTS"
  TWITTER_SMART_FILTER_REVOKED = "TWITTER_SMART_FILTER_REVOKED"

  # Contact Delete Forever Key
  CONTACT_DELETE_FOREVER_KEY = "CONTACT_DELETE_FOREVER:%{shard}"
  CONTACT_DELETE_FOREVER_MIN_TIME = "CONTACT_DELETE_FOREVER_MIN_TIME"
  CONTACT_DELETE_FOREVER_MAX_TIME = "CONTACT_DELETE_FOREVER_MAX_TIME"
  CONTACT_DELETE_FOREVER_CONCURRENCY = "CONTACT_DELETE_FOREVER_CONCURRENCY"

  #JWT api keys
  JWT_API_JTI = "JWT:%{account_id}:%{user_id}:%{jti}"
  ZENDESK_IMPORT_APP_KEY = "ZENDESK_IMPORT_APP"
  DISABLE_PORTAL_NEW_THEME = "DISABLE_PORTAL_NEW_THEME"
  BOT_STATUS = "BOT_STATUS:%{account_id}:%{bot_id}"

  # Key for enabling TAM company fields
  TAM_FIELDS_ENABLED = "TAM_FIELDS_ENABLED"

  YEAR_IN_REVIEW_ACCOUNT = "YEAR_IN_REVIEW:%{account_id}"
  YEAR_IN_REVIEW_CLOSED_USERS = "YEAR_IN_REVIEW_CLOSED:%{account_id}"

  FRESHID_CLIENT_CREDS_TOKEN_KEY = 'FRESHID_CLIENT_CREDS_TOKEN'.freeze
  FRESHID_USER_PW_AVAILABILITY = 'FRESHID_USER_PW_AVAILABILITY:%{account_id}:%{email}'.freeze
  FRESHID_NEW_ACCOUNT_SIGNUP_ENABLED = 'FRESHID_NEW_ACCOUNT_SIGNUP_ENABLED'.freeze
  FRESHWORKS_OMNIBAR_SIGNUP_ENABLED = 'FRESHWORKS_OMNIBAR_SIGNUP_ENABLED'.freeze
  FRESHID_MIGRATION_IN_PROGRESS_KEY = 'FRESHID_MIGRATION_IN_PROGRESS:%{account_id}'.freeze

  # Key for enabling TAM company fields
  TAM_FIELDS_ENABLED = "TAM_FIELDS_ENABLED"

  # Key for disabling collab bell
  COLLAB_BELL_DISABLED = 'COLLAB_BELL_DISABLED'.freeze

  TRIAL_21_DAYS = "TRIAL_21_DAYS"

  #Temp Redis keys for resque to sidekiq migration start
  SIDEKIQ_TOGGLE_AGENT_FROM_GROUPS = "SIDEKIQ_TOGGLE_AGENT_FROM_GROUPS"
  SIDEKIQ_RESTORE_SPAM_TICKETS = "SIDEKIQ_RESTORE_SPAM_TICKETS"
  SIDEKIQ_DISPATCH_SPAM_DIGEST = "SIDEKIQ_DISPATCH_SPAM_DIGEST"
  ADD_AGENT_TO_ROUND_ROBIN = 'ADD_AGENT_TO_ROUND_ROBIN'
  SIDEKIQ_GAMIFICATION_UPDATE_USER_SCORE = "SIDEKIQ_GAMIFICATION_UPDATE_USER_SCORE"
  SIDEKIQ_GAMIFICATION_PROCESS_TICKET_SCORE = "SIDEKIQ_GAMIFICATION_PROCESS_TICKET_SCORE"
  SIDEKIQ_GAMIFICATION_PROCESS_SOLUTION_QUESTS = "SIDEKIQ_GAMIFICATION_PROCESS_SOLUTION_QUESTS"
  SIDEKIQ_GAMIFICATION_PROCESS_POST_QUESTS = "SIDEKIQ_GAMIFICATION_PROCESS_POST_QUESTS"
  SIDEKIQ_GAMIFICATION_PROCESS_TOPIC_QUESTS = "SIDEKIQ_GAMIFICATION_PROCESS_TOPIC_QUESTS"
  SIDEKIQ_GAMIFICATION_PROCESS_TICKET_QUESTS = "SIDEKIQ_GAMIFICATION_PROCESS_TICKET_QUESTS"
  SIDEKIQ_NULLIFY_DELETED_CUSTOMFIELD_DATA = "SIDEKIQ_NULLIFY_DELETED_CUSTOMFIELD_DATA"
  SIDEKIQ_MERGE_TOPICS = "SIDEKIQ_MERGE_TOPICS"
  SIDEKIQ_MARKETO_QUEUE = "SIDEKIQ_MARKETO_QUEUE"
  JIRA_ACC_UPDATES_SIDEKIQ_ENABLED = "JIRA_ACC_UPDATES_SIDEKIQ_ENABLED"
  REPORT_POST_SIDEKIQ_ENABLED = "REPORT_POST_SIDEKIQ_ENABLED"
  FORUM_POSTS_SPAM_MARKER = "FORUM_POSTS_SPAM_MARKER".freeze
  SIDEKIQ_MARKETOQUEUE = "SIDEKIQ_MARKETO_QUEUE"
  SIDEKIQ_SUBSCRIPTIONS_ADD_DELETED_EVENT = "SIDEKIQ_SUBSCRIPTIONS_ADD_DELETED_EVENT"
  SIDEKIQ_ADD_SUBSCRIPTION_EVENTS = "SIDEKIQ_ADD_SUBSCRIPTION_EVENTS"
  SIDEKIQ_BAN_USER = "SIDEKIQ_BAN_USER"
  FRESHSALES_ADMIN_UPDATE = "FRESHSALES_ADMIN_UPDATE".freeze
  FRESHSALES_DELETED_CUSTOMER = "FRESHSALES_DELETED_CUSTOMER".freeze
  FRESHSALES_ACCOUNT_SIGNUP = "FRESHSALES_ACCOUNT_SIGNUP".freeze
  FRESHSALES_TRACK_SUBSCRIPTION = "FRESHSALES_TRACK_SUBSCRIPTION".freeze
  JIRA_ACC_UPDATES_SIDEKIQ_ENABLED = "JIRA_ACC_UPDATES_SIDEKIQ_ENABLED"
  REPORT_POST_SIDEKIQ_ENABLED              = "REPORT_POST_SIDEKIQ_ENABLED"
  SIDEKIQ_TOGGLE_AGENT_FROM_GROUPS = "SIDEKIQ_TOGGLE_AGENT_FROM_GROUPS"
  SIDEKIQ_DISPATCH_SPAM_DIGEST = "SIDEKIQ_DISPATCH_SPAM_DIGEST"

  #Temp Redis keys for resque to sidekiq migration end

  def newrelic_begin_rescue
    begin
      yield
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      return
    end
  end

  def set_members(key)
    newrelic_begin_rescue { $redis.smembers(key) }
  end

end




  #Temp Redis keys for resque to sidekiq migration end




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

