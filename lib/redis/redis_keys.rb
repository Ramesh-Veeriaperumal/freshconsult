module Redis::RedisKeys

  include Redis::Keys::DisplayId
  include Redis::Keys::Integrations
  include Redis::Keys::Marketplace
  include Redis::Keys::Mobile
  include Redis::Keys::Others
  include Redis::Keys::Portal
  include Redis::Keys::PrivateApiKeys
  include Redis::Keys::RateLimit
  include Redis::Keys::Reports
  include Redis::Keys::RoundRobin
  include Redis::Keys::Routes
  include Redis::Keys::Session
  include Redis::Keys::SpamWatcher
  include Redis::Keys::Tickets
  include Redis::Keys::Semaphore
  include Redis::Keys::AutomationRules
  include Redis::Keys::SidekiqBgOptions
  include Redis::Keys::Silkroad
  # Please do not any new key in this file.
  # Please add new key in respective file based on its redis host.

  #Timestamp key for Redis AOF reference.
  TIMESTAMP_REFERENCE = "TIMESTAMP_REFERENCE"

  #########################################################################################################

  # NOTE::
  # When you add a new redis key, please add the constant to the specific set of below array based on what type of key it is.
  # If its a new type, please define a new type and add it in delete_account.rb. The below keys are removed before account
  # destroy during account cancellation.
  ACCOUNT_RELATED_KEYS = [
    EMPTY_TRASH_TICKETS, EMPTY_SPAM_TICKETS, PORTAL_CACHE_VERSION, API_THROTTLER_V2, ACCOUNT_API_LIMIT, WEBHOOK_THROTTLER,
    WEBHOOK_THROTTLER_LIMIT_EXCEEDED, WEBHOOK_DROP_NOTIFY, REPORT_STATS_REGENERATE_KEY,
    REPORT_STATS_EXPORT_HASH, CUSTOM_SSL, SUBSCRIPTIONS_BILLING, ZENDESK_IMPORT_STATUS, ZENDESK_IMPORT_CUSTOM_DROP_DOWN,
    SPAM_MIGRATION, ADMIN_WIDGET_CACHE_SET, GROUP_WIDGET_CACHE_SET, ADMIN_WIDGET_CACHE_GET,
    GROUP_WIDGET_CACHE_GET, AGENT_LANGUAGE_LIST, CUSTOMER_LANGUAGE_LIST, OUTGOING_COUNT_PER_HALF_HOUR, OUTBOUND_EMAIL_COUNT_PER_DAY, YEAR_IN_REVIEW_CLOSED_USERS, YEAR_IN_REVIEW_ACCOUNT, ACTIVE_SUSPENDED, BACKGROUND_FIXTURES_STATUS, DASHBOARD_INDEX,
    ACCOUNT_CANCELLATION_REQUEST_JOB_ID, AUTOMATION_RULES_WITH_THANK_YOU_CONFIGURED, ACCOUNT_CANCELLATION_REQUEST_TIME
  ].freeze

  DISPLAY_ID_KEYS = [TICKET_DISPLAY_ID].freeze

  ACCOUNT_GROUP_KEYS = [
    GROUP_ROUND_ROBIN_AGENTS, ROUND_ROBIN_CAPPING, ROUND_ROBIN_CAPPING_PERMIT, RR_CAPPING_TICKETS_QUEUE,
    RR_CAPPING_TEMP_TICKETS_QUEUE, RR_CAPPING_TICKETS_DEFAULT_SORTED_SET
  ].freeze

  ACCOUNT_GROUP_USER_KEYS = [ROUND_ROBIN_AGENT_CAPPING].freeze

  ACCOUNT_USER_KEYS = [
    ADMIN_ROUND_ROBIN_FILTER, SOLUTION_DRAFTS_SCOPE, GAMIFICATION_QUEST_COOLDOWN, PERSISTENT_RECENT_TICKETS, SUPPORT_TICKET_LIMIT
  ].freeze

  ACCOUNT_AGENT_ID_KEYS = [STREAM_RECENT_SEARCHES].freeze

  ACCOUNT_HOST_KEYS = [API_THROTTLER].freeze

  ACCOUNT_ARTICLE_KEYS = [SOLUTION_HIT_TRACKER].freeze

  ACCOUNT_ARTICLE_VERSION_KEYS = [ARTICLE_VERSION_SESSION].freeze

  ACCOUNT_ARTICLE_META_KEYS = [SOLUTION_META_HIT_TRACKER].freeze

  ACCOUNT_TOPIC_KEYS = [TOPIC_HIT_TRACKER].freeze


  def newrelic_begin_rescue
    begin
      yield
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      return
    end
  end

end
