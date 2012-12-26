module Cache::Memcache::Customer

  include MemcacheKeys

  def clear_cache
    MemcacheKeys.delete_from_cache(ACCOUNT_CUSTOMERS % { :account_id =>self.account_id })
  end

end