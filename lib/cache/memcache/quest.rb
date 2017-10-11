module Cache::Memcache::Quest

  include MemcacheKeys

  def clear_quests_cache
    account.agents.preload(:user).each do |agent|
    	clear_quests_cache_for_user(agent.user)
    end
  end

  def clear_quests_cache_for_user(user)
  	MemcacheKeys.delete_from_cache(agent_quest_key(user))
  end

  def agent_quest_key(user)
    AVAILABLE_QUEST_LIST % { :account_id => account_id, :user_id => user.id}    
  end

end