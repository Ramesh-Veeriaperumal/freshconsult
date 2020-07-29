module Redis::OthersRedis
  def get_others_redis_key(key)
    newrelic_begin_rescue { $redis_others.perform_redis_op('get', key) }
  end

  def set_others_redis_key(key, value, expires = 86_400)
    newrelic_begin_rescue do
      $redis_others.perform_redis_op('set', key, value)
      $redis_others.perform_redis_op('expire', key, expires) if expires
    end
  end

  def get_set_others_redis_key(key, value, expires = nil)
    newrelic_begin_rescue do
      value = $redis_others.perform_redis_op('getset', key, value)
      $redis_others.perform_redis_op('expire', key, expires) if expires
      value
    end
  end

  def set_others_redis_key_if_not_present(key, value)
    newrelic_begin_rescue do
      $redis_others.perform_redis_op('setnx', key, value)
    end
  end

  def set_others_redis_with_expiry(key, value, options)
    newrelic_begin_rescue { $redis_others.perform_redis_op('set', key, value, options) }
  end

  def remove_others_redis_key(key)
    newrelic_begin_rescue { $redis_others.perform_redis_op('del', key) }
  end

  def set_others_redis_expiry(key, expires)
    newrelic_begin_rescue do
      $redis_others.perform_redis_op('expire', key, expires)
    end
  end

  def get_others_redis_expiry(key)
    newrelic_begin_rescue { $redis_others.perform_redis_op('ttl', key) }
  end

  def increment_others_redis(key, value = 1)
    newrelic_begin_rescue do
      $redis_others.perform_redis_op('INCRBY', key, value)
    end
  end

  def decrement_others_redis(key, value = 1)
    newrelic_begin_rescue do
      $redis_others.perform_redis_op('DECRBY', key, value)
    end
  end

  def redis_key_exists?(key)
    newrelic_begin_rescue { $redis_others.perform_redis_op('exists', key) }
  end

  def publish_to_channel(channel, message)
    newrelic_begin_rescue do
      return $redis_others.perform_redis_op('publish', channel, message)
    end
  end

  def get_others_redis_list(key, start = 0, stop = -1)
    newrelic_begin_rescue { $redis_others.perform_redis_op('lrange', key, start, stop) }
  end

  def get_others_redis_llen(key)
    newrelic_begin_rescue { $redis_others.perform_redis_op('llen', key) }
  end

  def set_others_redis_lpush(key, value)
    newrelic_begin_rescue { $redis_others.perform_redis_op('lpush', key, value) }
  end

  def get_others_redis_rpop(key)
    newrelic_begin_rescue { $redis_others.perform_redis_op('rpop', key) }
  end

  def get_others_redis_rpoplpush(source, destination)
    newrelic_begin_rescue { $redis_others.perform_redis_op('rpoplpush', source, destination) }
  end

  def get_others_redis_lrem(key, value, all = 0)
    newrelic_begin_rescue { $redis_others.perform_redis_op('lrem', key, all, value) }
  end

  def ismember?(key, value)
    newrelic_begin_rescue { $redis_others.perform_redis_op('sismember', key, value) }
  end

  def set_others_redis_hash(key, value)
    newrelic_begin_rescue { $redis_others.perform_redis_op('mapped_hmset', key, value) }
  end

  def get_others_redis_hash(key)
    newrelic_begin_rescue { $redis_others.perform_redis_op('hgetall', key) }
  end

  def del_other_redis_hash_value(key, members)
    newrelic_begin_rescue { $redis_others.perform_redis_op('hdel', key, members || []) }
  end

  def set_others_redis_hash_set(key, member, value)
    newrelic_begin_rescue { $redis_others.perform_redis_op('hset', key, member, value) }
  end

  def get_others_redis_hash_value(key, member)
    newrelic_begin_rescue { $redis_others.perform_redis_op('hget', key, member) }
  end

  def add_member_to_redis_set(key, member)
    newrelic_begin_rescue { $redis_others.perform_redis_op('sadd', key, member) }
  end

  def remove_member_from_redis_set(key, member)
    newrelic_begin_rescue { $redis_others.perform_redis_op('srem', key, member) }
  end

  def get_all_members_in_a_redis_set(key)
    newrelic_begin_rescue { $redis_others.perform_redis_op('smembers', key) }
  end

  def add_member_to_others_sorted_set(key, score, member, expires = 86_400)
    newrelic_begin_rescue do
      $redis_others.perform_redis_op('zadd', key, score, member)
      $redis_others.perform_redis_op('expire', key, expires) if expires
    end
  end

  def get_members_others_sorted_set_range(key, start, stop)
    newrelic_begin_rescue { $redis_others.perform_redis_op('zrange', key, start, stop) }
  end

  def remove_member_others_sorted_set(key, member)
    newrelic_begin_rescue { $redis_others.perform_redis_op('zrem', key, member) }
  end

  def remove_members_others_sorted_set_rank(key, start, stop)
    newrelic_begin_rescue { $redis_others.perform_redis_op('zremrangebyrank', key, start, stop) }
  end

  def get_multiple_others_redis_keys(*keys)
    newrelic_begin_rescue { $redis_others.perform_redis_op('mget', *keys) }
  end

  def watch_others_redis(key)
    newrelic_begin_rescue { $redis_others.perform_redis_op('watch', key) }
  end

  def exec_others_redis
    newrelic_begin_rescue { $redis_others.perform_redis_op('exec') }
  end
end
