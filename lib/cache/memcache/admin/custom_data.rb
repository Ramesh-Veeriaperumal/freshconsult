module Cache::Memcache::Admin::CustomData
  include MemcacheKeys

  def agent_groups_ids_only_from_cache
    key = agent_groups_ids_only_memcache_key
    fetch_from_cache(key) do
      agent_groups.write_access_only.pluck_all('user_id', 'group_id').each_with_object(agents: {}, groups: {}) do |ag, mapping|
        group_id = ag[AgentConstants::AGENT_GROUPS_ID_MAPPING[:group_id]]
        user_id = ag[AgentConstants::AGENT_GROUPS_ID_MAPPING[:user_id]]
        (mapping[:agents][user_id] ||= []).push(group_id)
        (mapping[:groups][group_id] ||= []).push(user_id)
      end
    end
  end

  def account_agent_details_from_cache
    key = agent_users_memcache_key
    fetch_from_cache(key) do
      agents.pluck_all('agents.id as agent_id', 'users.id as user_id', 'users.name as user_name',
                       'users.email as user_email', 'agents.agent_type as agent_type')
    end
  end

  private

    def agent_users_memcache_key
      format(AGENTS_USERS_VALUE, account_id: id)
    end

    def agent_groups_ids_only_memcache_key
      format(ACCOUNT_AGENT_GROUPS_ONLY_IDS, account_id: id)
    end
end
