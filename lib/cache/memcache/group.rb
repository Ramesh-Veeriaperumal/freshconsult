module Cache::Memcache::Group

  include MemcacheKeys

  def clear_cache
    MemcacheKeys.delete_from_cache(ACCOUNT_GROUPS % { :account_id =>self.account_id })
    MemcacheKeys.delete_from_cache(ACCOUNT_SUPPORT_AGENT_GROUPS % { :account_id =>self.account_id })
    MemcacheKeys.delete_from_cache(format(ACCOUNT_FIELD_AGENT_GROUPS, account_id: account_id))
  end

end
