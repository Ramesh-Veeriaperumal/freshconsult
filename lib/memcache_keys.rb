module MemcacheKeys

  include Cache::Memcache::Dashboard::MemcacheKeys

  AVAILABLE_QUEST_LIST = "AVAILABLE_QUEST_LIST:%{user_id}:%{account_id}"

  USER_TICKET_FILTERS = "v1/TICKET_VIEWS:%{user_id}:%{account_id}"

  ACCOUNT_CUSTOM_SURVEY = "v3/ACCOUNT_CUSTOM_SURVEY:%{account_id}"

  ACCOUNT_TICKET_TYPES = "v3/ACCOUNT_TICKET_TYPES:%{account_id}"

  ACCOUNT_AGENTS = "v4/ACCOUNT_AGENTS:%{account_id}"

  ACCOUNT_AGENTS_DETAILS = "v3/ACCOUNT_AGENTS_DETAILS:%{account_id}"

  ACCOUNT_ROLES = "v1/ACCOUNT_ROLES:%{account_id}"

  ACCOUNT_SUBSCRIPTION = "ACCOUNT_SUBSCRIPTION:%{account_id}"

  ACCOUNT_GROUPS = "v2/ACCOUNT_GROUPS:%{account_id}"

  ACCOUNT_PRODUCTS = "v1/ACCOUNT_PRODUCTS:%{account_id}"

  ACCOUNT_TAGS = "v1/ACCOUNT_TAGS:%{account_id}"

  ACCOUNT_COMPANIES = "v2/ACCOUNT_COMPANIES:%{account_id}"

  ACCOUNT_ONHOLD_CLOSED_STATUSES = "v1/ACCOUNT_ONHOLD_CLOSED_STATUSES:%{account_id}"

  ACCOUNT_STATUS_NAMES = "v2/ACCOUNT_STATUS_NAMES:%{account_id}"

  ACCOUNT_STATUSES = "v2/ACCOUNT_STATUSES:%{account_id}"

  ACCOUNT_STATUS_GROUPS = "v1/ACCOUNT_STATUS_GROUPS:%{account_id}"

  PORTAL_BY_URL = "v2/PORTAL_BY_URL:%{portal_url}"

  ACCOUNT_BY_FULL_DOMAIN = "v4/ACCOUNT_BY_FULL_DOMAIN:%{full_domain}"

  ACCOUNT_MAIN_PORTAL = "v3/ACCOUNT_MAIN_PORTAL:%{account_id}"

  ACCOUNT_CUSTOM_DROPDOWN_FIELDS = "v2/ACCOUNT_CUSTOM_DROPDOWN_FIELDS:%{account_id}"

  ACCOUNT_NESTED_FIELDS = "v3/ACCOUNT_NESTED_FIELDS:%{account_id}"

  ACCOUNT_EVENT_FIELDS = "v1/ACCOUNT_EVENT_FIELDS:%{account_id}"

  ACCOUNT_FLEXIFIELDS = "v1/ACCOUNT_FLEXIFIELDS:%{account_id}"

  ACCOUNT_TICKET_FIELDS = "v1/ACCOUNT_TICKET_FIELDS:%{account_id}"

  ACCOUNT_SECTION_FIELDS_WITH_FIELD_VALUE_MAPPING = "v1/ACCOUNT_SECTION_FIELDS_WITH_FIELD_VALUE_MAPPING:%{account_id}"

  ACCOUNT_OBSERVER_RULES = "v1/ACCOUNT_OBSERVER_RULES:%{account_id}"

  ACCOUNT_TWITTER_HANDLES = "v2/ACCOUNT_TWITTER_HANDLES:%{account_id}"

  FORUM_CATEGORIES = "v1/FORUM_CATEGORIES:%{account_id}"

  ALL_SOLUTION_CATEGORIES = "v1/ALL_SOLUTION_CATEGORIES:%{account_id}"

  CONTACT_FORM_FIELDS = "v1/CONTACT_FORM_FIELDS:%{account_id}:%{contact_form_id}"

  COMPANY_FORM_FIELDS = "v1/COMPANY_FORM_FIELDS:%{account_id}:%{company_form_id}"

  # ES_ENABLED_ACCOUNTS = "ES_ENABLED_ACCOUNTS"

  # Portal customization related keys
  PORTAL_TEMPLATE = "v2/PORTAL_TEMPLATE:%{account_id}:%{portal_id}"

  PORTAL_TEMPLATE_PAGE = "v1/PORTAL_TEMPLATE_PAGE:%{account_id}:%{template_id}:%{page_type}"

  SOLUTION_CATEGORIES = "v1/SOLUTION_CATEGORIES:%{portal_id}"

  FB_REAUTH_CHECK = "v1/FB_REAUTH_CHECK:%{account_id}"

  FB_REALTIME_MSG_ENABLED = "v1/FB_REALTIME_MSG_ENABLED:%{account_id}"

  TWITTER_REAUTH_CHECK = "v1/TWITTER_REAUTH_CHECK:%{account_id}"

  WHITELISTED_IP_FIELDS = "v3/WHITELISTED_IP_FIELDS:%{account_id}"

  FEATURES_LIST = "v4/FEATURES_LIST:%{account_id}"

  SHARD_BY_DOMAIN = "v4/SHARD_BY_DOMAIN:%{domain}"

  SHARD_BY_ACCOUNT_ID = "v4/SHARD_BY_ACCOUNT_ID:%{account_id}"

  DEFAULT_BUSINESS_CALENDAR = "v1/DEFAULT_BUSINESS_CALENDAR:%{account_id}"

  ACCOUNT_AGENT_NAMES = "AGENT_NAMES:%{account_id}"

  GLOBAL_BLACKLISTED_IPS = "v1/GLOBAL_BLACKLISTED_IPS"

  WHITELISTED_USERS = "v1/WHITELISTED_USERS"

  API_LIMIT = "v1/API_LIMIT:%{account_id}"

  ACCOUNT_API_WEBHOOKS_RULES = "v1/ACCOUNT_API_WEBHOOKS_RULES:%{account_id}"

  ACCOUNT_INSTALLED_APP_BUSINESS_RULES = "v1/ACCOUNT_INSTALLED_APP_BUSINESS_RULES:%{account_id}"

  SALES_MANAGER_3_DAYS = "v1/SALES_MANAGER_3_DAYS:%{account_id}"

  FRESH_SALES_MANAGER_3_DAYS = "v1/FRESH_SALES_MANAGER_3_DAYS:%{account_id}"

  SALES_MANAGER_1_MONTH = "v1/SALES_MANAGER_1_MONTH:%{account_id}"

  FRESH_SALES_MANAGER_1_MONTH = "v1/FRESH_SALES_MANAGER_1_MONTH:%{account_id}"

  MOBIHELP_APP = "MOBIHELP_APP:%{account_id}:%{app_key}"

  MOBIHELP_SOLUTION_CATEGORY_IDS = "MOBIHELP_SOLUTION_CATEGORY_IDS:%{account_id}:%{app_key}"

  MOBIHELP_SOLUTIONS = "v1/MOBIHELP_SOLUTIONS:%{account_id}:%{category_id}"

  MOBIHELP_SOLUTION_UPDATED_TIME = "v3/MOBIHELP_SOLUTION_UPDATED_TIME:%{account_id}:%{app_id}"

  PRODUCT_NOTIFICATION = "v3/%{language}/PRODUCT_NOTIFICATION"

  POD_SHARD_ACCOUNT_MAPPING = "v2/POD_SHARD_ACCOUNT_MAPPING:%{pod_info}:%{shard_name}"

  ACCOUNT_ADDITIONAL_SETTINGS = "v3/ACCOUNT_ADDITIONAL_SETTINGS:%{account_id}"

  INSTALLED_FRESHPLUGS = "v2/FA:%{page}:PLUGS:%{account_id}"

  FRESHPLUG_CODE = "v1/FA:PLUG:%{version_id}"

  EXTENSION_CATEGORIES = "v1/FA:EXTENSION_CATEGORIES"

  MKP_EXTENSIONS = "v1/FA:MKP_EXTENSIONS:%{category_id}:%{type}:%{locale_id}:%{sort_by}"
  
  CUSTOM_APPS = "v1/FA:CUSTOM_APPS:%{account_id}:%{locale_id}"

  EXTENSION_DETAILS = "v2/FA:EXTENSION:%{extension_id}:%{locale_id}"

  CONFIGURATION_DETAILS = "v1/FA:CONFIGURATIONS:%{version_id}:%{locale_id}"

  INSTALLED_CTI_APP = "v1/INSTALLED_CTI_APP:%{account_id}"

  ECOMMERCE_REAUTH_CHECK = "v1/ECOMMERCE_REAUTH_CHECK:%{account_id}"

  ACCOUNT_PASSWORD_POLICY = "v1/ACCOUNT_PASSWORD_POLICIES:%{account_id}:%{user_type}"

  HELPDESK_PERMISSIBLE_DOMAINS = "v1/HELPDESK_PERMISSIBLE_DOMAINS:%{account_id}"

  LEADERBOARD_MINILIST_REALTIME = "v2/LEADERBOARD_MINILIST_REALTIME:%{account_id}:%{agent_type}"

  REQUESTER_WIDGET_FIELDS = "v1/REQUESTER_WIDGET_FIELDS:%{account_id}"

  AGENT_NEW_TICKET_FORM = "v2/AGENT_NEW_TICKET_FORM:%{account_id}:%{language}"

  ACCOUNT_INSTALLED_APPS_IN_COMPANY_PAGE = "V1/ACCOUNT_INSTALLED_APPS_IN_COMPANY_PAGE:%{account_id}"

  COMPOSE_EMAIL_FORM = "v2/COMPOSE_EMAIL_FORM:%{account_id}:%{language}"

  TKT_TEMPLATES_COUNT = "v1/TKT_TEMPLATES_COUNT:%{account_id}"

  ACCOUNT_WEBHOOK_KEY = "ACCOUNT_WEBHOOK_KEY:%{account_id}:%{vendor_id}"

  MOST_VIEWED_ARTICLES = "MOST_VIEWED_ARTICLES:%{account_id}:%{language_id}:%{cache_version}"

  class << self

    include MemcacheReadWriteMethods

    def agent_type(user) #pass user as argument
      user.can_view_all_tickets? ? "UNRESTRICTED" :  "RESTRICTED"
    end

    def memcache_local_key(key, account=Account.current, user=User.current)
      key % {:account_id => account.id, :agent_type => agent_type(user) , :user_id => user.id}
    end

    def memcache_view_key(key, account=Account.current, user=User.current)
      "views/#{memcache_local_key(key, account, user)}"
    end

    def memcache_delete(key, account=Account.current, user=User.current)
      newrelic_begin_rescue { memcache_client.delete(memcache_view_key(key, account, user)) } 
    end

    def memcache_client
      $memcache
    end
  end
end
