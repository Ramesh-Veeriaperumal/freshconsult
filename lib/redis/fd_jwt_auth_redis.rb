module Redis::FdJWTAuthRedis

  def set_jwt_redis_with_expiry(key, value, options)
    newrelic_begin_rescue { $redis_session.perform_redis_op("set", key, value, options) }
  end

  def redis_key_exists?(key)
    newrelic_begin_rescue { $redis_session.perform_redis_op("exists", key) }
  end

end
