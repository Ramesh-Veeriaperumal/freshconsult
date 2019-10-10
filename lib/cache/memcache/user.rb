module Cache::Memcache::User
  include MemcacheKeys

  def clear_agent_list_cache
    delete_value_from_cache(format(ACCOUNT_AGENTS, account_id: account_id))
    delete_value_from_cache(format(ACCOUNT_AGENTS_DETAILS, account_id: account_id))
    delete_value_from_cache(format(ACCOUNT_AGENTS_DETAILS_OPTAR, account_id: account_id))
    delete_value_from_cache(format(ACCOUNT_AGENTS_HASH, account_id: account_id))
  end

  def clear_agent_name_cache
    delete_value_from_cache(format(ACCOUNT_AGENT_NAMES, account_id: self.account_id))
  end

  def clear_agent_details_cache
    delete_value_from_cache(format(AGENTS_USERS_VALUE, account_id: account_id))
    delete_value_from_cache(format(ACCOUNT_AGENTS_DETAILS_PLUCK, account_id: self.account_id))
  end

  def clear_cache
    clear_agent_list_cache
    clear_agent_name_cache
    clear_agent_details_cache
  end
end
