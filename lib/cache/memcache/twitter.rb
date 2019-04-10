module Cache::Memcache::Twitter

  include MemcacheKeys

  def clear_cache
    MemcacheKeys.delete_from_cache(format(TWITTER_REAUTH_CHECK, account_id: self.account_id))
  end
  
  def clear_handles_cache
    delete_value_from_cache(format(ACCOUNT_TWITTER_HANDLES, account_id: self.account_id))
  end

  def clear_twitter_handles_cache
    delete_value_from_cache(format(ACCOUNT_TWITTER_HANDLES, account_id: Account.current.id))
  end
  
end