module Cache::Memcache::Twitter

  include MemcacheKeys

  def clear_cache
  	MemcacheKeys.delete_from_cache(TWITTER_REAUTH_CHECK % { :account_id =>self.account_id })
  end
  
end