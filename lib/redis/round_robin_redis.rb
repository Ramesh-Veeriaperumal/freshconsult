module Redis::RoundRobinRedis

  def get_round_robin_redis key
    $redis_round_robin.perform_redis_op("get", key)
  end

  def set_round_robin_redis key, value
    $redis_round_robin.perform_redis_op("set", key, value)
  end

  def exists_round_robin_redis key
    $redis_round_robin.perform_redis_op("exists", key)
  end

  def del_round_robin_redis *key
    $redis_round_robin.perform_redis_op("del", *key)
  end

  def incr_round_robin_redis key
    $redis_round_robin.perform_redis_op("incr", key)
  end

  def decr_round_robin_redis key
    $redis_round_robin.perform_redis_op("decr", key)
  end

  def sadd_round_robin_redis key, value
    $redis_round_robin.perform_redis_op("sadd", key, value)
  end

  def smembers_round_robin_redis key
    $redis_round_robin.perform_redis_op("smembers", key)
  end

  def srem_round_robin_redis key, value
    $redis_round_robin.perform_redis_op("srem", key, value)
  end

  def lpush_round_robin_redis key, value
    $redis_round_robin.perform_redis_op("lpush", key, value)
  end

  def rpush_round_robin_redis key, value
    $redis_round_robin.perform_redis_op("rpush", key, value)
  end

  def lpop_round_robin_redis key
    $redis_round_robin.perform_redis_op("lpop", key)
  end

  def lrem_round_robin_redis key, value, count=0
    $redis_round_robin.perform_redis_op("lrem", key, count, value)
  end

  def lrange_round_robin_redis key, start_index, end_index
    $redis_round_robin.perform_redis_op("lrange", start_index, end_index)
  end

  def zadd_round_robin_redis key, score, value
    $redis_round_robin.perform_redis_op("zadd", key, score, value)
  end

  def zrange_round_robin_redis key, start_index, end_index, with_scores=false
    $redis_round_robin.perform_redis_op("zrange", key, start_index, end_index, 
                                          :with_scores => with_scores)
  end

  def zscore_round_robin_redis key, value
    $redis_round_robin.perform_redis_op("zscore", key, value)
  end

  def zrem_round_robin_redis key, member
    $redis_round_robin.perform_redis_op("zrem", key, member)
  end

  def watch_round_robin_redis key
    $redis_round_robin.perform_redis_op("watch", key)
  end

  def multi_round_robin_redis
    $redis_round_robin.perform_redis_op("multi")
  end

  def exec_round_robin_redis
    $redis_round_robin.perform_redis_op("exec")
  end

end
