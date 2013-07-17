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
end