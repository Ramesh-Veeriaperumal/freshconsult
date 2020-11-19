# frozen_string_literal: true

module Cache::Memcache::Group
  include MemcacheKeys

  def clear_cache
    delete_value_from_cache(format(ACCOUNT_GROUPS, account_id: account_id))
    delete_value_from_cache(format(ACCOUNT_SUPPORT_AGENT_GROUPS, account_id: account_id))
    delete_value_from_cache(format(ACCOUNT_FIELD_AGENT_GROUPS, account_id: account_id))
  end
end
