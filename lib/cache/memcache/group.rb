module Cache::Memcache::Group

  include MemcacheKeys

  def clear_cache
    MemcacheKeys.delete_from_cache(ACCOUNT_GROUPS % { :account_id =>self.account_id })
  end

end