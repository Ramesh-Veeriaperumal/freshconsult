module MemcacheKeys

  LEADERBOARD_MINILIST = "HELPDESK_LEADERBOARD_MINILIST:%{agent_type}:%{account_id}"

  AVAILABLE_QUEST_LIST = "AVAILABLE_QUEST_LIST:%{user_id}:%{account_id}"

  USER_TICKET_FILTERS = "v1/TICKET_VIEWS:%{user_id}:%{account_id}"

  ACCOUNT_TICKET_TYPES = "v2/ACCOUNT_TICKET_TYPES:%{account_id}"

  ACCOUNT_AGENTS = "v3/ACCOUNT_AGENTS:%{account_id}"

  ACCOUNT_GROUPS = "v2/ACCOUNT_GROUPS:%{account_id}"

  ACCOUNT_PRODUCTS = "v1/ACCOUNT_PRODUCTS:%{account_id}"

  ACCOUNT_TAGS = "v1/ACCOUNT_TAGS:%{account_id}"

  ACCOUNT_CUSTOMERS = "v1/ACCOUNT_CUSTOMERS:%{account_id}"

  ACCOUNT_ONHOLD_CLOSED_STATUSES = "v1/ACCOUNT_ONHOLD_CLOSED_STATUSES:%{account_id}"

  ACCOUNT_STATUS_NAMES = "v2/ACCOUNT_STATUS_NAMES:%{account_id}"

  ACCOUNT_STATUSES = "v2/ACCOUNT_STATUSES:%{account_id}"


  PORTAL_BY_URL = "v2/PORTAL_BY_URL:%{portal_url}"

  ACCOUNT_BY_FULL_DOMAIN = "v2/ACCOUNT_BY_FULL_DOMAIN:%{full_domain}"

  ACCOUNT_MAIN_PORTAL = "v3/ACCOUNT_MAIN_PORTAL:%{account_id}"

  ACCOUNT_CUSTOM_DROPDOWN_FIELDS = "v1/ACCOUNT_CUSTOM_DROPDOWN_FIELDS:%{account_id}"

  ACCOUNT_NESTED_FIELDS = "v1/ACCOUNT_NESTED_FIELDS:%{account_id}"

  ES_ENABLED_ACCOUNTS = "ES_ENABLED_ACCOUNTS"
 
  # Portal customization related keys
  PORTAL_TEMPLATE = "v2/PORTAL_TEMPLATE:%{account_id}:%{portal_id}"

  PORTAL_TEMPLATE_PAGE = "v1/PORTAL_TEMPLATE_PAGE:%{account_id}:%{template_id}:%{page_type}"

  SOLUTION_CATEGORIES = "v1/SOLUTION_CATEGORIES:%{portal_id}"

  FB_REAUTH_CHECK = "v1/FB_REAUTH_CHECK:%{account_id}"

  TWITTER_REAUTH_CHECK = "v1/TWITTER_REAUTH_CHECK:%{account_id}"

  SHARD_BY_DOMAIN = "v1/SHARD_BY_DOMAIN:%{domain}"
 
  SHARD_BY_ACCOUNT_ID = "v1/SHARD_BY_ACCOUNT_ID:%{account_id}"
  
  class << self

    def newrelic_begin_rescue(&block)
      begin
        block.call
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
        return
      end 
    end

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
      newrelic_begin_rescue { $memcache.delete(memcache_view_key(key, account, user)) } 
    end

    def get_from_cache(key)
      newrelic_begin_rescue { $memcache.get(key) }
    end

    def cache(key,value,expiry=0)
      newrelic_begin_rescue { $memcache.set(key, value, expiry) }
    end

    def delete_from_cache(key)
      newrelic_begin_rescue { $memcache.delete(key) }
    end

    def fetch(key, expiry=0,&block)
      key = ActiveSupport::Cache.expand_cache_key(key) if key.is_a?(Array)
      cache_data = get_from_cache(key)
      if cache_data.nil?
        Rails.logger.debug "Cache hit missed :::::: #{key}"
        cache(key, (cache_data = block.call), expiry)
      end
      cache_data
    end
  end
  
end