class AgentGroupObserver < ActiveRecord::Observer

  include MemcacheKeys
  include Redis::RedisKeys
  include Redis::OthersRedis

  def before_create(agent_group)
    set_account_id(agent_group)
  end

  def after_commit(agent_group)
    clear_redis_for_group(agent_group)
  end

  def after_destroy(agent_group)
    clear_cache(agent_group)
  end
  

  private

    def set_account_id(agent_group)
      agent_group.account_id = agent_group.user.account_id
    end

    #When an agent group is created, clear redis array of agent ids for that group.
    #This is only for groups that have round robin scheduling.
    def clear_redis_for_group(agent_group)
      remove_others_redis_key(GROUP_AGENT_TICKET_ASSIGNMENT % { :account_id => agent_group.account_id, 
                                                                :group_id => agent_group.group_id})
    end

    def auto_refresh_key(agent_group)
      AUTO_REFRESH_AGENT_DETAILS % { :account_id => agent_group.account_id, :user_id => agent_group.user_id }
    end

    def clear_cache(agent_group)
      key = auto_refresh_key(agent_group)
      MemcacheKeys.delete_from_cache key
    end
end