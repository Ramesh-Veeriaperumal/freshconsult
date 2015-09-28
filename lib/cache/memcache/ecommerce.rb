module Cache::Memcache::Ecommerce

  include MemcacheKeys

  def clear_cache
  	MemcacheKeys.delete_from_cache(ECOMMERCE_REAUTH_CHECK % { :account_id =>self.account_id })
  end
  
end