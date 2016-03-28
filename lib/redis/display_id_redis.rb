module Redis::DisplayIdRedis

  def get_display_id_redis_key key
    $redis_display_id.perform_redis_op("get", key)
  end

  def set_display_id_redis_key(key, value)
    $redis_display_id.perform_redis_op("set", key, value)
  end

  def set_display_id_redis_with_expiry(key, value, options)
    $redis_display_id.perform_redis_op("set", key, value, options)
  end

  def increment_display_id_redis_key key, value = 1
    $redis_display_id.perform_redis_op("INCRBY", key, value)
  end
end
