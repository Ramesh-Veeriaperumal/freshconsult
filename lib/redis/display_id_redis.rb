module Redis::DisplayIdRedis

  def get_display_id_redis_key key
    newrelic_begin_rescue { $redis_display_id.get(key) }
  end

  def set_display_id_redis_key(key, value)
    newrelic_begin_rescue { $redis_display_id.set(key, value) }
  end

  def set_display_id_redis_with_expiry(key, value, options)
    newrelic_begin_rescue { $redis_display_id.set(key, value, options) }
  end

  def increment_display_id_redis_key key, value = 1
    newrelic_begin_rescue { $redis_display_id.INCRBY(key, value) }
  end
end
