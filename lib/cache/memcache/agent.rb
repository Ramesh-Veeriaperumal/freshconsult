module Cache::Memcache::Agent

  include MemcacheKeys
	
  def clear_available_quests_cache!
    MemcacheKeys.memcache_delete(AVAILABLE_QUEST_LIST)
  end

  def all_agent_groups_from_cache
    key = all_agent_groups_cache_key
    fetch_from_cache(key) do
      all_agent_groups
    end
  end

  private

    def all_agent_groups_cache_key
      format(ALL_AGENT_GROUPS_CACHE_FOR_AN_AGENT, account_id: Account.current.id, user_id: user_id)
    end
end
