# frozen_string_literal: true

module Cache::Memcache::User
  include MemcacheKeys

  def user_roles_from_cache
    fetch_from_cache(user_roles_memcache_key) { roles.all }
  end

  def clear_agent_list_cache
    delete_value_from_cache(format(ACCOUNT_AGENTS, account_id: account_id))
    delete_value_from_cache(format(ACCOUNT_AGENTS_DETAILS, account_id: account_id))
    delete_value_from_cache(format(ACCOUNT_AGENTS_DETAILS_OPTAR, account_id: account_id))
    delete_value_from_cache(format(ACCOUNT_AGENTS_HASH, account_id: account_id))
  end

  def clear_user_roles_cache
    delete_value_from_cache(user_roles_memcache_key)
  end

  def clear_agent_name_cache
    delete_value_from_cache(format(ACCOUNT_AGENT_NAMES, account_id: self.account_id))
  end

  def clear_agent_details_cache
    delete_value_from_cache(format(AGENTS_USERS_VALUE, account_id: account_id))
  end

  def clear_cache
    clear_agent_list_cache
    clear_agent_name_cache
    clear_agent_details_cache
  end

  private

    def user_roles_memcache_key
      format(ACCOUNT_USER_ROLES, account_id: account_id, user_id: id)
    end
end
