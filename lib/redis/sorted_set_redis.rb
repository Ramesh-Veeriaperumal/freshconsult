module Redis::SortedSetRedis

  def multi_actions_sorted_set_redis
    newrelic_begin_rescue do
      $redis_others.perform_redis_op "multi"
      yield
      $redis_others.perform_redis_op "exec"
    end
  end

  def key_exists_sorted_set_redis(key)
    newrelic_begin_rescue { $redis_others.perform_redis_op("exists", key) }
  end

  def add_in_sorted_set_redis(key, score, member, expires = 86400)
    multi_actions_sorted_set_redis do
      $redis_others.perform_redis_op("zadd", key, score, member)
      $redis_others.perform_redis_op("expire", key, expires) if expires
    end
  end

  def multi_add_in_sorted_set_redis(key, value, expires = 86400)
    multi_actions_sorted_set_redis do
      $redis_others.perform_redis_op("zadd", key, value)
      $redis_others.perform_redis_op("expire", key, expires)
    end
  end

  def size_of_sorted_set_redis(key)
    newrelic_begin_rescue { $redis_others.perform_redis_op("zcard", key) }
  end

  def get_index_from_sorted_set_redis(key, member)
    newrelic_begin_rescue { $redis_others.perform_redis_op("zrank", key, member) }
  end

  def get_member_at_sorted_set_redis(key, index)
    newrelic_begin_rescue { $redis_others.perform_redis_op("zrange", key, index, index, {:withscores => true}) }
  end

  def incr_score_of_sorted_set_redis(key, member, value = 1)
    newrelic_begin_rescue do 
      score = $redis_others.perform_redis_op("zincrby", key, value, member)
      delete_member_sorted_set_redis(key, member) if score == 0.0
    end
  end

  def delete_member_sorted_set_redis(key, member)
    newrelic_begin_rescue { $redis_others.perform_redis_op("zrem", key, member) }
  end

  def get_all_members_of_sorted_set_redis(key)
    size = size_of_sorted_set_redis key
    newrelic_begin_rescue { $redis_others.perform_redis_op("zrange", key, 0, size, {:withscores => true}) }
  end

  def get_largest_members_of_sorted_set_redis(key, count = 1)
    newrelic_begin_rescue { $redis_others.perform_redis_op("zrevrange", key, 0, count - 1, {:withscores => true}) }
  end

end