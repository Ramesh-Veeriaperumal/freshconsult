module Redis::HashMethods
  def multi_set_redis_hash(redis_key, array_of_key_values, expires = nil)
    newrelic_begin_rescue do
      $redis_others.perform_redis_op('hmset', redis_key, array_of_key_values)
      $redis_others.perform_redis_op('expire', redis_key, expires) if expires
    end
  end

  def multi_get_redis_hash(redis_key, array_of_keys)
    newrelic_begin_rescue { $redis_others.perform_redis_op('hmget', redis_key, array_of_keys) }
  end

  def set_key_in_redis_hash(redis_key, key, value)
    newrelic_begin_rescue { $redis_others.perform_redis_op('hset', redis_key, key, value ) }
  end

  def delete_key_in_redis_hash(redis_key, key)
    newrelic_begin_rescue { $redis_others.perform_redis_op('hdel', redis_key, key) }
  end

  def multi_get_all_redis_hash(redis_key)
    newrelic_begin_rescue { $redis_others.perform_redis_op('hgetall', redis_key) }
  end
end
