module Redis::Keys::Others

  PREVIEW_URL                             = "PREVIEW_URL:%{account_id}:%{user_id}:%{portal_id}".freeze
  EMAIL_TICKET_ID                         = "EMAIL_TICKET_ID:%{account_id}:%{message_id}".freeze
  MINT_PREVIEW_KEY                        = "MINT_PREVIEW_KEY:%{account_id}:%{user_id}:%{portal_id}"
  MIGRATED_EMAIL_TICKET_ID                = "MIGRATED_EMAIL_TICKET_ID:%{account_id}:%{email_config_id}:%{message_id}".freeze
  ADMIN_ROUND_ROBIN_FILTER                = "ADMIN_ROUND_ROBIN_FILTER:%{account_id}:%{user_id}".freeze
  ACCOUNT_ONBOARDING_PENDING              = "ACCOUNT_ONBOARDING_PENDING:%{account_id}".freeze
  ACCOUNT_ONBOARDING_VERSION              = "ACCOUNT_ONBOARDING_VERSION".freeze
  TAG_BASED_ARTICLE_SEARCH                = "TAG_BASED_ARTICLE_SEARCH".freeze
  WEBHOOK_THROTTLER                       = "WEBHOOK_THROTTLER:%{account_id}".freeze
  WEBHOOK_THROTTLER_LIMIT_EXCEEDED        = "WEBHOOK_THROTTLER_LIMIT_EXCEEDED:%{account_id}".freeze
  WEBHOOK_ERROR_NOTIFICATION              = "WEBHOOK_ERROR_NOTIFICATION:%{account_id}:%{rule_id}".freeze
  PREMIUM_GAMIFICATION_ACCOUNT            = "PREMIUM_GAMIFICATION_ACCOUNT".freeze
  WEBHOOK_DROP_NOTIFY                     = "WEBHOOK_DROP_NOTIFY:%{account_id}".freeze
  GOOGLE_OAUTH_SSO                        = "GOOGLE_OAUTH_SSO:%{random_key}".freeze
  FACEBOOK_APP_RATE_LIMIT                 = "FACEBOOK_APP_RATE_LIMIT".freeze
  FACEBOOK_LIKES                          = "FACEBOOK_LIKES".freeze
  FACEBOOK_USER_RATE_LIMIT                = "FACEBOOK_USER_RATE_LIMIT:%{page_id}".freeze
  FACEBOOK_PAGE_RATE_LIMIT                = "FACEBOOK_PAGE_RATE_LIMIT:%{account_id}:%{page_id}".freeze
  FACEBOOK_API_HIT_COUNT                  = "FACEBOOK_API_HIT_COUNT:%{page_id}".freeze
  CLASSIC_REPORTS_ENABLED                 = "CLASSIC_REPORTS_ENABLED".freeze
  USER_EMAIL_MIGRATED                     = "user_email_migrated".freeze
  OLD_REPORTS_ENABLED                     = "OLD_REPORTS_ENABLED".freeze
  CUSTOM_SSL                              = "CUSTOM_SSL:%{account_id}".freeze
  SUBSCRIPTIONS_BILLING                   = "SUBSCRIPTIONS_BILLING:%{account_id}".freeze
  SEARCH_KEY                              = "SEARCH_KEY:%{account_id}:%{klass_name}:%{id}".freeze
  STREAM_RECENT_SEARCHES                  = "STREAM_RECENT_SEARCHES:%{account_id}:%{agent_id}".freeze
  STREAM_VOLUME                           = "STREAM_VOLUME:%{account_id}:%{stream_id}".freeze
  SPAM_MIGRATION                          = "SPAM_MIGRATION:%{account_id}".freeze
  SPAM_EMAIL_ACCOUNTS                     = "SPAM_EMAIL_ACCOUNTS".freeze
  PREMIUM_EMAIL_ACCOUNTS                  = "PREMIUM_EMAIL_ACCOUNTS".freeze
  SOLUTION_HIT_TRACKER                    = "SOLUTION:HITS:%{account_id}:%{article_id}".freeze
  SOLUTION_META_HIT_TRACKER               = "SOLUTION_META:HITS:%{account_id}:%{article_meta_id}".freeze
  ARTICLE_VERSION_SESSION                 = 'ARTICLE_VERSION_SESSION:%{account_id}:%{article_id}:%{version_id}'.freeze
  ARTICLE_VERSION_LOCK_KEY                = 'ARITLCE_VERSION_LOCK_KEY:%{account_id}:%{article_id}'.freeze
  TOPIC_HIT_TRACKER                       = "TOPIC:HITS:%{account_id}:%{topic_id}".freeze
  MESSAGE_PROCESS_STATE                   = "MESSAGE_PROCESS_STATE:%{uid}".freeze
  MESSAGE_RETRY_STATE                     = "MESSAGE_RETRY_STATE:%{uid}".freeze
  PROCESS_EMAIL_PROGRESS                  = "PROCESS_EMAIL:%{account_id}:%{unique_key}".freeze
  PROCESSED_TICKET_DATA                   = "PROCESSED_TICKET_DATA:%{uid}".freeze
  SELECT_ALL                              = "SELECT_ALL:%{account_id}".freeze
  SOLUTION_DRAFTS_SCOPE                   = "SOLUTION:DRAFTS:%{account_id}:%{user_id}".freeze
  UPDATE_PASSWORD_EXPIRY                  = "UPDATE_PASSWORD_EXPIRY:%{account_id}:%{user_type}".freeze
  CARD_FAILURE_COUNT                      = "CREDIT_CARD_FAILURE_COUNT:%{account_id}".freeze
  EMAIL_CONFIG_BLACKLISTED_DOMAINS        = "email_config_blacklisted_domains".freeze
  EMAIL_TEMPLATE_SPAM_DOMAINS             = "EMAIL_TEMPLATE_SPAM_DOMAINS".freeze
  SPAM_USER_EMAIL_DOMAINS                 = "SPAM_USER_EMAIL_DOMAINS".freeze
  SPAM_CHECK_TEMPLATE_FLAGGED_RULES       = "SPAM_CHECK_TEMPLATE_FLAGGED_RULES".freeze
  GAMIFICATION_QUEST_COOLDOWN             = "GAMIFICATION:QUEST:%{account_id}:%{user_id}".freeze
  GAMIFICATION_AGENTS_LEADERBOARD         = "GAMIFICATION_AGENTS_LEADERBOARD:%{account_id}:%{category}:%{month}".freeze
  GAMIFICATION_GROUPS_LEADERBOARD         = "GAMIFICATION_GROUPS_LEADERBOARD:%{account_id}:%{category}:%{month}".freeze
  GAMIFICATION_GROUP_AGENTS_LEADERBOARD   = "GAMIFICATION_GROUP_AGENTS_LEADERBOARD:%{account_id}:%{category}:%{month}:%{group_id}".freeze
  MULTI_FILE_ATTACHMENT                   = "MULTI_FILE_ATTACHMENT:%{date}".freeze
  EMPTY_TRASH_TICKETS                     = "EMPTY_TRASH_TICKETS:%{account_id}".freeze
  EMPTY_SPAM_TICKETS                      = "EMPTY_SPAM_TICKETS:%{account_id}".freeze
  CARD_EXPIRY_KEY                         = "CARD_EXPIRY_KEY:%{account_id}".freeze
  DISABLE_FRESHSALES_API_CALLS            = 'DISABLE_FRESHSALES_API_CALLS'.freeze
  # List of languages used by agents in an account
  AGENT_LANGUAGE_LIST                     = "AGENT_LANGUAGE_LIST:%{account_id}".freeze
  # List of languges used by customers in an account
  CUSTOMER_LANGUAGE_LIST                  = "CUSTOMER_LANGUAGE_LIST:%{account_id}".freeze
  PERSISTENT_RECENT_SEARCHES              = "PERSISTENT_RECENT_SEARCHES:%{account_id}:%{user_id}".freeze
  PERSISTENT_RECENT_TICKETS               = "PERSISTENT_RECENT_TICKETS:%{account_id}:%{user_id}".freeze
  SPAM_REPORTS_COUNT                      = "SPAM_REPORTS_COUNT:%{account_id}".freeze
  MAX_SPAM_REPORTS_ALLOWED                = "MAX_SPAM_REPORTS_ALLOWED:%{state}".freeze
  PROCESSING_FAILED_HELPKIT_FEEDS         = "PROCESSING_FAILED_HELPKIT_FEEDS".freeze
  PROCESSING_FAILED_CENTRAL_FEEDS         = "PROCESSING_FAILED_CENTRAL_FEEDS".freeze
  OUTGOING_COUNT_PER_HALF_HOUR            = "OUTGOING_COUNT_PER_HALF_HOUR:%{account_id}".freeze
  SPAM_ACCOUNT_ID_THRESHOLD               = "SPAM_ACCOUNT_ID_THRESHOLD".freeze
  SPAM_OUTGOING_EMAILS_THRESHOLD          = "SPAM_OUTGOING_EMAILS_THRESHOLD".freeze
  OUTBOUND_EMAIL_COUNT_PER_DAY            = "OUTBOUND_EMAIL_COUNT_PER_DAY:%{account_id}".freeze
  TRIAL_ACCOUNT_MAX_TO_CC_THRESHOLD       = "TRIAL_ACCOUNT_MAX_TO_CC_THRESHOLD".freeze
  FREE_ACCOUNT_OUTBOUND_THRESHOLD         = "FREE_ACCOUNT_OUTBOUND_THRESHOLD".freeze
  SPAM_BLACKLISTED_RULES                  = "SPAM_BLACKLISTED_RULES".freeze
  EMAIL_THRESHOLD_CROSSED_TICKETS         = "EMAIL_THRESHOLD_CROSSED_TICKETS:%{account_id}".freeze
  SPAM_WHITELISTED_ACCOUNTS               = "SPAM_WHITELISTED_ACCOUNTS".freeze
  SPAM_ACCOUNT_TIME_LIMIT                 = "SPAM_ACCOUNT_TIME_LIMIT".freeze
  JWT_SSO_JTI                             = "JTI_%{account_id}_%{jti}".freeze
  COUNT_ESV2_WRITE_ENABLED                = "COUNT_ESV2_WRITE_ENABLED".freeze
  COUNT_ESV2_READ_ENABLED                 = "COUNT_ESV2_READ_ENABLED".freeze
  MAILGUN_EVENT_LAST_SYNC                 = "MAILGUN_EVENT_LAST_SYNC:%{domain}".freeze
  SIGNUP_RESTRICTED_DOMAINS               = "SIGNUP_RESTRICTED_DOMAINS".freeze
  SIGNUP_RESTRICTED_EMAIL_DOMAINS         = "SIGNUP_RESTRICTED_EMAIL_DOMAINS".freeze
  # Email sender config redis key
  EMAIL_SENDER_CONFIG                     = "EMAIL_SENDER_CONFIG:%{account_id}:%{email_type}".freeze
  # Key to hold the "From" of various language. This helps in identifying the original sender while agent forward
  AGENT_FORWARD_FROM_REGEX                = "AGENT_FORWARD_FROM_REGEX".freeze
  # Key to hold the "To" of various language. This helps in identifying the original recipient while agent forward
  AGENT_FORWARD_TO_REGEX                  = "AGENT_FORWARD_TO_REGEX".freeze
  #From regex of different languages used in quoted text parsing
  QUOTED_TEXT_PARSE_FROM_REGEX            = "QUOTED_TEXT_PARSE_FROM_REGEX".freeze
  #deprecated style parsing in email html content
  DEPRECATED_STYLE_PARSING                = "DEPRECATED_STYLE_PARSING:%{account_id}".freeze
  # key for enabling fd email service to all the account
    # keys for switching the email traffic to mailgun
  TRIAL_MAILGUN_TRAFFIC_PERCENTAGE        = "TRIAL_MAILGUN_TRAFFIC_PERCENTAGE".freeze
  ACTIVE_MAILGUN_TRAFFIC_PERCENTAGE       = "ACTIVE_MAILGUN_TRAFFIC_PERCENTAGE".freeze
  PREMIUM_MAILGUN_TRAFFIC_PERCENTAGE      = "PREMIUM_MAILGUN_TRAFFIC_PERCENTAGE".freeze
  FREE_MAILGUN_TRAFFIC_PERCENTAGE         = "FREE_MAILGUN_TRAFFIC_PERCENTAGE".freeze
  DEFAULT_MAILGUN_TRAFFIC_PERCENTAGE      = "DEFAULT_MAILGUN_TRAFFIC_PERCENTAGE".freeze
  SPAM_MAILGUN_TRAFFIC_PERCENTAGE         = "SPAM_MAILGUN_TRAFFIC_PERCENTAGE".freeze
  QUOTED_TEXT_PARSING_NOT_REQUIRED        = "QUOTED_TEXT_PARSING_NOT_REQUIRED".freeze
  ROUTE_NOTIFICATIONS_VIA_EMAIL_SERVICE   = "ROUTE_NOTIFICATIONS_VIA_EMAIL_SERVICE".freeze
  ROUTE_EMAILS_VIA_FD_SMTP_SERVICE        = "ROUTE_EMAILS_VIA_FD_SMTP_SERVICE".freeze
  BLACKLISTED_SPAM_DOMAINS                = "BLACKLISTED_SPAM_DOMAINS".freeze
  SPAM_EMAIL_EXACT_REGEX_KEY              = "SPAM_EMAIL_EXACT_REGEX".freeze
  SPAM_EMAIL_APPRX_REGEX_KEY              = "SPAM_EMAIL_APPRX_REGEX".freeze
  CROSS_DOMAIN_API_GET_DISABLED           = "CROSS_DOMAIN_API_GET_DISABLED".freeze
  ACCOUNT_SETUP                           = "ACCOUNT_SETUP:%{account_id}".freeze
  NEW_SIGNUP_ENABLED                      = "NEW_SIGNUP_ENABLED".freeze
  META_DATA_TIMESTAMP                     = "META_DATA_TIMESTAMP".freeze
  ACCOUNT_ADMIN_ACTIVATION_JOB_ID         = "ACCOUNT_ADMIN_ACTIVATION_JOB_ID:%{account_id}".freeze
  DASHBOARD_FEATURE_ENABLED_KEY           = "DASHBOARD_FEATURE_ENABLED_KEY".freeze
  DASHBOARD_INDEX                         = "DASHBOARD_INDEX:%{account_id}".freeze
  ACCOUNT_SIGN_UP_PARAMS                  = "ACCOUNT_SIGN_UP_PARAMS:%{account_id}".freeze
  MARKETPLACE_APP_TICKET_DETAILS          = "MARKETPLACE_APP_TICKET_DETAILS:%{account_id}".freeze
  AUTOMATION_TICKET_PARAMS                = "AUTOMATION_TICKET_PARAMS:%{account_id}:%{ticket_id}".freeze
  ARTICLE_SPAM_REGEX                      = "ARTICLE_SPAM_REGEX".freeze
  FORUM_POST_SPAM_REGEX                   = "FORUM_POST_SPAM_REGEX".freeze
  PHONE_NUMBER_SPAM_REGEX                 = "PHONE_NUMBER_SPAM_REGEX".freeze
  CONTENT_SPAM_CHAR_REGEX                 = "CONTENT_SPAM_CHAR_REGEX".freeze
  DKIM_CATEGORY_KEY                       = "DKIM_CATEGORY_CHANGER".freeze
  DKIM_VERIFICATION_KEY                   = "DKIM_VERIFICATION:%{account_id}:%{email_domain_id}".freeze
  DKIM_CONFIGURATION_IN_PROGRESS_KEY      = "DKIM_CONFIGURATION_IN_PROGRESS".freeze
  BACKGROUND_FIXTURES_ENABLED             = "BACKGROUND_FIXTURES_ENABLED".freeze
  BACKGROUND_FIXTURES_STATUS              = "BACKGROUND_FIXTURES_STATUS:%{account_id}".freeze
  ACTIVE_SUSPENDED                        = "ACTIVE_SUSPENDED:%{account_id}".freeze
  CLEARBIT_NOTIFICATION                   = "CLEARBIT_NOTIFICATION".freeze
  CUSTOM_CATEGORY_NOTIFICATIONS           = "CUSTOM_CATEGORY_NOTIFICATIONS".freeze
  CUSTOM_BOT_RULES                        = "CUSTOM_BOT_RULES".freeze
  SPAM_FILTERED_NOTIFICATIONS             = "SPAM_FILTERED_NOTIFICATIONS".freeze
  FACEBOOK_PREMIUM_ACCOUNTS               = "FACEBOOK_PREMIUM_ACCOUNTS".freeze
  TWITTER_SMART_FILTER_REVOKED            = "TWITTER_SMART_FILTER_REVOKED".freeze
  REVOKE_SUPPORT_BOT                      = "REVOKE_SUPPORT_BOT".freeze
  # Contact Delete Forever Key
  CONTACT_DELETE_FOREVER_KEY              = "CONTACT_DELETE_FOREVER:%{shard}".freeze
  CONTACT_DELETE_FOREVER_MIN_TIME         = "CONTACT_DELETE_FOREVER_MIN_TIME".freeze
  CONTACT_DELETE_FOREVER_MAX_TIME         = "CONTACT_DELETE_FOREVER_MAX_TIME".freeze
  CONTACT_DELETE_FOREVER_CONCURRENCY      = "CONTACT_DELETE_FOREVER_CONCURRENCY".freeze
  CLAMAV_CONNECTION_ERROR_TIMEOUT         = "CLAMAV_CONNECTION_ERROR_TIMEOUT".freeze
  WHITELISTED_DOMAINS_KEY                 = "WHITELISTED_DOMAINS_KEY".freeze
  UNDO_SEND_BODY_KEY                      = "UNDO_SEND_BODY_KEY:%{account_id}:%{user_id}:%{ticket_id}:%{created_at}".freeze
  UNDO_SEND_KEY                           = "UNDO_SEND_KEY:%{account_id}:%{user_id}:%{ticket_id}:%{created_at}:SEND".freeze
  UNDO_SEND_REPLY_ENQUEUE                 = "UNDO_SEND_REPLY_ENQUEUE:%{account_id}:%{ticket_id}".freeze
  ZENDESK_IMPORT_APP_KEY                  = "ZENDESK_IMPORT_APP".freeze
  DISABLE_PORTAL_NEW_THEME                = "DISABLE_PORTAL_NEW_THEME".freeze
  BOT_STATUS                              = "BOT_STATUS:%{account_id}:%{bot_id}".freeze
  YEAR_IN_REVIEW_ACCOUNT                  = "YEAR_IN_REVIEW:%{account_id}".freeze
  YEAR_IN_REVIEW_CLOSED_USERS             = "YEAR_IN_REVIEW_CLOSED:%{account_id}".freeze
  UPDATE_TIME_ZONE                        = "UPDATE_TIME_ZONE:%{account_id}".freeze
  ADVANCED_TICKETING_METRICS              = "ADVANCED_TICKETING_METRICS".freeze
  FRESHCONNECT_NEW_ACCOUNT_SIGNUP_ENABLED = "FRESHCONNECT_NEW_ACCOUNT_SIGNUP_ENABLED".freeze
  CANNED_FORMS                            = "CANNED_FORMS:%<account_id>s".freeze
  SANDBOX_DIFF_RATE_LIMIT                 = "SANDBOX_DIFF_RATE_LIMIT".freeze
  # Search Service Keys
  #Dashboard v2 caching keys
  ADMIN_WIDGET_CACHE_SET                  = "ADMIN_WIDGET_CACHE_SET:%{account_id}".freeze
  GROUP_WIDGET_CACHE_SET                  = "GROUP_WIDGET_CACHE_SET:%{account_id}".freeze
  ADMIN_WIDGET_CACHE_GET                  = "ADMIN_WIDGET_CACHE_GET:%{account_id}".freeze
  GROUP_WIDGET_CACHE_GET                  = "GROUP_WIDGET_CACHE_GET:%{account_id}".freeze
  # Feature related or temporary keys
  COMPOSE_EMAIL_ENABLED                   = "COMPOSE_EMAIL_ENABLED".freeze
  DASHBOARD_DISABLED                      = "DASHBOARD_DISABLED".freeze
  RESTRICTED_COMPOSE                      = "RESTRICTED_COMPOSE".freeze
  SLAVE_QUERIES                           = "SLAVE_QUERIES".freeze
  MASTER_QUERIES                          = "MASTER_QUERIES".freeze
  VALIDATE_REQUIRED_TICKET_FIELDS         = "VALIDATE_REQUIRED_TICKET_FIELDS".freeze
  PLUGS_IN_NEW_TICKET                     = "PLUGS_IN_NEW_TICKET".freeze
  # Zendesk import related
  ZENDESK_IMPORT_STATUS                    = "ZENDESK_IMPORT_STATUS:%{account_id}".freeze
  ZENDESK_IMPORT_CUSTOM_DROP_DOWN          = "ZENDESK_IMPORT_CUSTOM_DROP_DOWN_%{account_id}".freeze
  MOBILE_NOTIFICATION_REGISTRATION_CHANNEL = "MOBILE_NOTIFICATION_REGISTRATION_CHANNEL".freeze

  # CUSTOMER IMPORT KEYS
  CONTACT_IMPORT_TOTAL_RECORDS = "CONTACT_IMPORT_TOTAL_RECORDS:%{account_id}:%{import_id}"
  CONTACT_IMPORT_FINISHED_RECORDS = "CONTACT_IMPORT_FINISHED_RECORDS:%{account_id}:%{import_id}"
  CONTACT_IMPORT_FAILED_RECORDS = "CONTACT_IMPORT_FAILED_RECORDS:%{account_id}:%{import_id}"
  COMPANY_IMPORT_TOTAL_RECORDS = "COMPANY_IMPORT_TOTAL_RECORDS:%{account_id}:%{import_id}"
  COMPANY_IMPORT_FINISHED_RECORDS = "COMPANY_IMPORT_FINISHED_RECORDS:%{account_id}:%{import_id}"
  COMPANY_IMPORT_FAILED_RECORDS = "CCOMPANY_IMPORT_FAILED_RECORDS:%{account_id}:%{import_id}"
  STOP_CONTACT_IMPORT = "STOP_CONTACT_IMPORT:%{account_id}"
  STOP_COMPANY_IMPORT = "STOP_COMPANY_IMPORT:%{account_id}"

  SUPERVISOR_TICKETS_LIMIT                 = "SUPERVISOR_TICKETS_LIMIT".freeze
  SLA_TICKETS_LIMIT                        = "SLA_TICKETS_LIMIT".freeze
  DETECT_USER_LANGUAGE                     = "DETECT_USER_LANGUAGE:%{text}".freeze
  SPAM_NOTIFICATION_WHITELISTED_DOMAINS_EXPIRY = "SPAM_NOTIFICATION_WHITELISTED_DOMAINS:%{account_id}".freeze
  RECENT_ACCOUNT_SPAM_FILTERED_NOTIFICATIONS   = "RECENT_ACCOUNT_SPAM_FILTERED_NOTIFICATIONS".freeze
  INVOICE_DUE                                  = "INVOICE_DUE:%{account_id}".freeze

  #Account cancellation related keys
  ACCOUNT_CANCELLATION_REQUEST_JOB_ID = "ACCOUNT_CANCELLATION_REQUEST_JOB_ID:%{account_id}".freeze
  ACCOUNT_CANCELLATION_REQUEST_TIME = "ACCOUNT_CANCELLATION_REQUEST_TIME:%{account_id}".freeze
  CUSTOM_ENCRYPTED_FIELD_KEY               = "CF_ENC_ENCRYPTION_KEY:%{account_id}".freeze

  # FreshID Keys
  FRESHID_CLIENT_CREDS_TOKEN_KEY          = 'FRESHID_CLIENT_CREDS_TOKEN'.freeze
  FRESHID_V2_CLIENT_CREDS_TOKEN_KEY       = 'FRESHID_V2_CLIENT_CREDS_TOKEN_KEY'.freeze
  FRESHID_V2_ORG_CLIENT_CREDS_TOKEN_KEY   = 'FRESHID_V2_ORG_CLIENT_CREDS_TOKEN_KEY:%{organisation_domain}'.freeze
  FRESHID_USER_PW_AVAILABILITY            = 'FRESHID_USER_PW_AVAILABILITY:%{account_id}:%{email}'.freeze
  FRESHID_NEW_ACCOUNT_SIGNUP_ENABLED      = 'FRESHID_NEW_ACCOUNT_SIGNUP_ENABLED'.freeze
  FLUFFY_HOUR_SIGNUP_ENABLED              = 'FLUFFY_HOUR_SIGNUP_ENABLED'.freeze
  FLUFFY_MINUTE_SIGNUP_ENABLED            = 'FLUFFY_MINUTE_SIGNUP_ENABLED'.freeze
  FRESHWORKS_OMNIBAR_SIGNUP_ENABLED       = 'FRESHWORKS_OMNIBAR_SIGNUP_ENABLED'.freeze
  FRESHID_MIGRATION_IN_PROGRESS_KEY       = 'FRESHID_MIGRATION_IN_PROGRESS:%{account_id}'.freeze
  FRESHID_V2_NEW_ACCOUNT_SIGNUP_ENABLED   = 'FRESHID_V2_NEW_ACCOUNT_SIGNUP_ENABLED'.freeze
  FRESHID_ORG_V2_USER_ACCESS_TOKEN        = 'FRESHID_ORG_V2_USER_ACCESS_TOKEN:%{account_id}:%{user_id}'.freeze
  FRESHID_ORG_V2_USER_REFRESH_TOKEN       = 'FRESHID_ORG_V2_USER_REFRESH_TOKEN:%{account_id}:%{user_id}'.freeze

  TWITTER_APP_BLOCKED = 'TWITTER_APP_BLOCKED'.freeze

  ANONYMOUS_ACCOUNT_SIGNUP_ENABLED  = 'ANONYMOUS_ACCOUNT_SIGNUP_ENABLED'.freeze
  ACCOUNT_SIGNUP_IN_PROGRESS        = 'ACCOUNT_SIGNUP_IN_PROGRESS:%{domain}'.freeze
  ACCOUNT_DOMAIN_FS_COOKIE          = 'ACCOUNT_DOMAIN_FS_COOKIE:%{domain}'.freeze

  SYSTEM42_SUPPORTED_LANGUAGES = 'SYSTEM42_SUPPORTED_LANGUAGES'.freeze

  # Proactive service
  CUSTOM_EMAIL_OUTREACH_LIMIT = "CUSTOM_EMAIL_OUTREACH_LIMIT".freeze
  #Customer segments max limit
  SEGMENT_LIMIT = "SEGMENT_LIMIT:%{account_id}".freeze

  # Enable logs for specific account when supressed
  ENABLE_LOGS = 'ENABLE_LOGS:%{account_id}'.freeze

  BULK_OPERATIONS_RATE_LIMIT_BATCH_SIZE = 'BULK_OPERATIONS_RATE_LIMIT_BATCH_SIZE:%{class_name}'.freeze
  BULK_OPERATIONS_RATE_LIMIT_NEXT_RUN_AT = 'BULK_OPERATIONS_RATE_LIMIT_NEXT_RUN_AT:%{class_name}'.freeze
  INDIVIDUAL_BATCH_SIZE_KEY = 'INDIVIDUAL_BATCH_SIZE:%{class_name}'.freeze

  ENABLE_NEXT_RESPONSE_SLA = 'ENABLE_NEXT_RESPONSE_SLA'.freeze
  ENABLE_THANK_YOU_DETECTOR = 'ENABLE_THANK_YOU_DETECTOR'.freeze
  FSM_GA_LAUNCHED = 'FSM_GA_LAUNCHED'.freeze
  CLD_FD_LANGUAGE_MAPPING = 'CLD_FD_LANGUAGE_MAPPING'.freeze

  DOWNGRADE_POLICY_EMAIL_REMINDER = 'DOWNGRADE_POLICY_EMAIL_REMINDER:%{account_id}'.freeze

  SUPPORT_TICKET_LIMIT = "SUPPORT_TICKET_LIMIT:%{account_id}%{user_id}".freeze

  CUSTOM_MAILBOX_STATUS_CHECK = 'CUSTOM_MAILBOX_STATUS_CHECK'.freeze
  REAUTH_MAILBOX_STATUS_CHECK = 'REAUTH_MAILBOX_STATUS_CHECK'.freeze
  MAILBOX_OAUTH = 'OAUTH:%{provider}:%{account_id}:%{user_id}:%{random_number}'.freeze
  OAUTH_ACCESS_TOKEN_VALIDITY = 'OAUTH_ACCESS_TOKEN:%{provider}:%{account_id}:%{smtp_mailbox_id}'.freeze

  #Increasing Domains for accounts as per request by the account holder
  INCREASE_DOMAIN_FOR_EMAILS = 'INCREASE_DOMAIN_FOR_EMAILS'.freeze

  # Field service management
  FSM_SIGN_UP_ENABLED_PAGES_LIST = 'FSM_SIGN_UP_ENABLED_PAGES_LIST'.freeze

  # Holds the pages to be migrated to the us app
  MIGRATE_EUC_FB_PAGES = 'MIGRATE_EUC_FB_PAGES:%{account_id}'.freeze

  # Holds the manually configured domains for accounts
  MIGRATE_MANUALLY_CONFIGURED_DOMAINS = 'MIGRATE_MANUALLY_CONFIGURED_DOMAINS:%{account_id}'.freeze

  ACTIVE_RECORD_LOG = 'ACTIVE_RECORD_LOG'.freeze

  ACCOUNT_ACTIVATED_WITHIN_LAST_WEEK = 'ACCOUNT_ACTIVATED_WITHIN_LAST_WEEK:%{account_id}'.freeze
  AGENTS_COUNT_KEY = 'AGENTS_COUNT_KEY:%{account_id}'.freeze

  CONDITION_BASED_LAUNCHPARTY_FEATURES = 'CONDITION_BASED_LAUNCHPARTY_FEATURES'.freeze
  CONDITION_BASED_OMNI_LAUNCHPARTY_FEATURES = 'CONDITION_BASED_OMNI_LAUNCHPARTY_FEATURES'.freeze

  # Holds the processed job details for ticket status deletion
  TICKET_STATUS_DELETION_JOBS = 'TICKET_STATUS_DELETION_JOBS:%{account_id}:%{status_id}'.freeze
  LATEST_SHARDS = 'LATEST_SHARDS_FROM_REDIS'.freeze
  TWITTER_API_COMPLIANCE_ENABLED = 'TWITTER_API_COMPLIANCE_ENABLED'.freeze

  FRESHID_MIGRTATION_SSO_ALLOWED = 'FRESHID_MIGRTATION_SSO_ALLOWED'.freeze
  FRESHID_MIGRTATION_PORTAL_CUSTOMIZATION_ALLOWED = 'FRESHID_MIGRTATION_PORTAL_CUSTOMIZATION_ALLOWED'.freeze
  FRESHID_MIGRTATION_PASSWORD_POLICY_ALLOWED = 'FRESHID_MIGRTATION_PASSWORD_POLICY_ALLOWED'.freeze
  FRESHID_MIGRATION_DISABLED_ACCOUNT_FRESHOPS = 'FRESHID_MIGRATION_DISABLED_ACCOUNT_FRESHOPS'.freeze
  FRESHID_VALIDATION_TIMEOUT = 'FRESHID_VALIDATION_TIMEOUT:%{account_id}'.freeze
  SUPPRESS_FRESHID_V1_MIG_AGENT_NOTIFICATION = 'SUPPRESS_FRESHID_V1_MIG_AGENT_NOTIFICATION:%{account_id}'.freeze


  MARKETPLACE_NI_PAID_APP = 'MARKETPLACE_NI_PAID_APP:%{account_id}:%{app_name}'.freeze

  AGENT_CHAT_MANAGEMENT = 'AGENT_CHAT_MANAGEMENT'.freeze

  EMBERIZE_AGENT_FORM = 'EMBERIZE_AGENT_FORM'.freeze

  # Global account specify redis keys
  ACCOUNT_SETTINGS_REDIS_HASH = 'account_settings_redis_hash:%{account_id}'.freeze

  PERISHABLE_TOKEN_EXPIRY = 'PERISHABLE_TOKEN_EXPIRY:%{account_id}:%{user_id}'.freeze
  AUTHORIZATION_CODE_EXPIRY = 'AUTHORIZATION_CODE_EXPIRY:%{account_id}'.freeze
  PRECREATED_ACCOUNTS_SHARD = 'PRECREATED_ACCOUNTS:%{current_shard}'.freeze
  PRECREATE_ACCOUNT_ENABLED = 'PRECREATE_ACCOUNT_ENABLED'.freeze
  PRECREATE_OMNI_SIGNUP_ENABLED = 'PRECREATE_OMNI_SIGNUP_ENABLED'.freeze
  EMAIL_RATE_LIMIT_COUNT = 'EMAIL_RATE_LIMIT_COUNT:%{account_id}:%{hour_quadrant}'.freeze
  EMAIL_RATE_LIMIT_BREACHED = 'EMAIL_RATE_LIMIT_BREACHED:%{account_id}'.freeze
  EMAIL_RATE_LIMIT_ADMIN_NOTIFIED = 'EMAIL_RATE_LIMIT_ADMIN_NOTIFIED:%{account_id}'.freeze

  # Holds worker count for Central Resync
  CENTRAL_RESYNC_RATE_LIMIT = 'CENTRAL_RESYNC_RATE_LIMIT:%{source}'.freeze
  CENTRAL_RESYNC_MAX_ALLOWED_WORKERS = 'CENTRAL_RESYNC_MAX_ALLOWED_WORKERS'.freeze
  CENTRAL_RESYNC_MAX_ALLOWED_RECORDS = 'CENTRAL_RESYNC_MAX_ALLOWED_RECORDS'.freeze
  CENTRAL_RESYNC_JOB_STATUS = 'CENTRAL_RESYNC_JOB_STATUS:%{source}:%{job_id}'.freeze
  EMAIL_RATE_LIMIT_DEDUP = 'EMAIL_RATE_LIMIT_DEDUP:%{account_id}:%{minute}'.freeze
  OMNI_AGENT_AVAILABILITY_DASHBOARD = 'OMNI_AGENT_AVAILABILITY_DASHBOARD'.freeze
  AGENT_STATUSES_ENABLED_ON_SIGNUP = 'AGENT_STATUSES_ENABLED_ON_SIGNUP'.freeze

  ADVANCED_TICKET_SCOPES_ON_SIGNUP = 'ADVANCED_TICKET_SCOPES_ON_SIGNUP'.freeze

  # Content Security Policy for Agent Portal
  CONTENT_SECURITY_POLICY_AGENT_PORTAL = 'CONTENT_SECURITY_POLICY_AGENT_PORTAL'.freeze

  OMNI_ACCOUNTS_MONITORING_MAILING_LIST = 'OMNI_ACCOUNTS_MONITORING_MAILING_LIST'.freeze
  OMNI_ACCOUNTS_MONITORING_START_TIME = 'OMNI_ACCOUNTS_MONITORING_START_TIME'.freeze
  OMNI_ACCOUNTS_MONITORING_STOP_EXECUTION = 'OMNI_ACCOUNTS_MONITORING_STOP_EXECUTION'.freeze
  OCR_TO_MARS_CHAT_ACCOUNT_IDS = 'OCR_TO_MARS_CHAT_ACCOUNT_IDS'.freeze
  OCR_TO_MARS_CALLER_ACCOUNT_IDS = 'OCR_TO_MARS_CALLER_ACCOUNT_IDS'.freeze
  AGENT_STATUSES_CALLER_ACCOUNT_IDS = 'AGENT_STATUSES_CALLER_ACCOUNT_IDS'.freeze
  OMNI_TEAM_DASHBOARD_ENABLED_ON_SIGNUP = 'OMNI_TEAM_DASHBOARD_ENABLED_ON_SIGNUP'.freeze
end
