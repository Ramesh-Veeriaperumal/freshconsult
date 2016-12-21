module Cache::Memcache::Agent

  include MemcacheKeys
	
  def clear_available_quests_cache!
    MemcacheKeys.memcache_delete(AVAILABLE_QUEST_LIST)
  end

end