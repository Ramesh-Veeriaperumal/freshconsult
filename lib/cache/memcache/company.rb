module Cache::Memcache::Company
  include MemcacheKeys

  def clear_cache
    MemcacheKeys.delete_from_cache(format(ACCOUNT_COMPANIES, account_id: account_id))
    MemcacheKeys.delete_from_cache(format(ACCOUNT_COMPANIES_OPTAR, account_id: account_id))
  end
end
