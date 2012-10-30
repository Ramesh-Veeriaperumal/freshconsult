module Cache::Memcache::Agent

  include MemcacheKeys
	
  def clear_leaderboard_cache! #Refactor this code!
    MemcacheKeys.memcache_delete(LEADERBOARD_MINILIST)
  end

  def clear_available_quests_cache!
    MemcacheKeys.memcache_delete(AVAILABLE_QUEST_LIST)
  end
end