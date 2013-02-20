module Cache::Memcache::Facebook

  include MemcacheKeys

  def clear_cache
  	MemcacheKeys.delete_from_cache(FB_REAUTH_CHECK % { :account_id =>self.account_id })
  end
  
end