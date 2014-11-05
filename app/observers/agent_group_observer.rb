class AgentGroupObserver < ActiveRecord::Observer

  include MemcacheKeys
  include Redis::RedisKeys
  include Redis::OthersRedis

  def before_create(agent_group)
    set_account_id(agent_group)
  end

  def after_commit_on_create(agent_group)
    #enqueue in resque to avoid duplicate when list is created in group callback
    group = agent_group.group
    if group.round_robin_enabled?
      Resque.enqueue(Helpdesk::AddAgentToRoundRobin, 
            { :account_id => agent_group.account_id,
              :user_id => agent_group.user_id,
              :group_id => agent_group.group_id }) #maintain state for new key
      group.delete_old_round_robin_key #deprecated will be deleted soon
    end
  end

  def after_destroy(agent_group)
    clear_cache(agent_group)
    group = agent_group.group

    group.remove_agent_from_round_robin(agent_group.user_id) if group.round_robin_enabled?
  end

  private

    def set_account_id(agent_group)
      agent_group.account_id = agent_group.user.account_id
    end

    def auto_refresh_key(agent_group)
      AUTO_REFRESH_AGENT_DETAILS % { :account_id => agent_group.account_id, :user_id => agent_group.user_id }
    end

    def clear_cache(agent_group)
      key = auto_refresh_key(agent_group)
      MemcacheKeys.delete_from_cache key
    end

end