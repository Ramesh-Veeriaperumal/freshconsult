module Cache::Memcache::Company

  include MemcacheKeys

  def clear_cache
    MemcacheKeys.delete_from_cache(ACCOUNT_COMPANIES % { :account_id =>self.account_id })
  end

end