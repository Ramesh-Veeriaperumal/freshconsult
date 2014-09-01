module Cache::Memcache::Product

  include MemcacheKeys

  def clear_cache
    MemcacheKeys.delete_from_cache(ACCOUNT_PRODUCTS % { :account_id =>self.account_id })
  end

end