module Dashboard::Custom::CacheKeys
  include Cache::Memcache::Dashboard::Custom::MemcacheKeys
  include Redis::RedisKeys

  def dashboard_cache_key(dashboard_id)
    CUSTOM_DASHBOARD % { account_id: Account.current.id, dashboard_id: dashboard_id }
  end

  def dashboard_index_redis_key
    DASHBOARD_INDEX % { account_id: Account.current.id }
  end
end
