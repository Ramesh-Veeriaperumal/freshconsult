module Redis::MarketplaceAppRedis
  include Redis::RedisKeys

  def detail_key(account_id)
    MARKETPLACE_APP_TICKET_DETAILS % { :account_id => account_id }
  end

  def set_marketplace_app_redis_key(key, score, value)
    $redis_others.perform_redis_op("zadd", key, score, value)
  end

  def get_marketplace_app_redis_key(key, value)
    $redis_others.perform_redis_op("zscore", key, value)
  end

  def sorted_range_marketplace_app_redis_key(key, min, max)
    $redis_others.perform_redis_op("zrangebyscore", key, min, max)
  end

  def get_all_marketplace_app_redis_key(key)
    $redis_others.perform_redis_op("zrange", key, 0, -1, {:with_scores => false})
  end

  def count_marketplace_app_redis_key(key)
    $redis_others.perform_redis_op("zcard", key)
  end

  def remove_marketplace_app_redis_key(key, value)
    $redis_others.perform_redis_op("zrem", key, value)
  end

  def delete_marketplace_app_redis_key(key)
    $redis_others.perform_redis_op("del", key)
  end

  # - Automation params -

  def automation_params_key(account_id, ticket_id)
    AUTOMATION_TICKET_PARAMS % { :account_id => account_id, :ticket_id => ticket_id }
  end

  def set_automation_params_redis_key(hash, key, value)
    $redis_others.perform_redis_op("hset", hash, key, value)
  end

  def get_automation_params_redis_key(hash, key)
    $redis_others.perform_redis_op("hget", hash, key)
  end

  def remove_automation_params_redis_key(hash, key)
    $redis_others.perform_redis_op("hdel", hash, key)
  end

  def queued_for_marketplace_app?(account_id, ticket_id)
    key = automation_params_key(account_id, ticket_id)
    $redis_others.perform_redis_op("exists", key)
  end
end