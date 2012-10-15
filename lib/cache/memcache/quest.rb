module Cache::Memcache::Quest

  include MemcacheKeys

  def clear_quests_cache
    account.agents.each do |agent|
    	clear_quests_cache_for_user(agent.user)
    end
  end

  def clear_quests_cache_for_user(user)
  	MemcacheKeys.memcache_delete(AVAILABLE_QUEST_LIST, account, user)
  end

end