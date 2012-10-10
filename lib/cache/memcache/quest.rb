module Cache::Memcache::Quest

  include MemcacheKeys

  def clear_quests_cache(agents=nil)
  	agents = account.agents unless agents
    agents.each do |agent|
      MemcacheKeys.memcache_delete(AVAILABLE_QUEST_LIST, account, agent.user)
    end
  end

end