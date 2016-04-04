class AgentGroupObserver < ActiveRecord::Observer

  include MemcacheKeys
  include Redis::RedisKeys
  include Redis::OthersRedis

  def before_create(agent_group)
    set_account_id(agent_group)
  end

  def after_commit(agent_group)
    #enqueue in resque to avoid duplicate when list is created in group callback
    if agent_group.send(:transaction_include_action?, :create)
      group = agent_group.group
      if group.round_robin_enabled?
        Resque.enqueue(Helpdesk::AddAgentToRoundRobin, 
              { :account_id => agent_group.account_id,
                :user_id => agent_group.user_id,
                :group_id => agent_group.group_id }) #maintain state for new key
      end
    end
    true
  end

  def after_destroy(agent_group)
    clear_cache(agent_group)
    group = agent_group.group

    group.remove_agent_from_round_robin(agent_group.user_id) if group.round_robin_enabled?
  end

  private

    def set_account_id(agent_group)
      agent_group.account_id = agent_group.user.account_id unless agent_group.user.blank?
    end

    def auto_refresh_key(agent_group)
      AUTO_REFRESH_AGENT_DETAILS % { :account_id => agent_group.account_id, :user_id => agent_group.user_id }
    end

    def clear_cache(agent_group)
      key = auto_refresh_key(agent_group)
      MemcacheKeys.delete_from_cache key
    end

end