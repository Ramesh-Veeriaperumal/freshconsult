module Redis::SortedSetRedis

  def multi_actions_sorted_set_redis
    newrelic_begin_rescue do
      $redis_others.multi do |connection|
        yield(connection)
      end
    end
  end

  def key_exists_sorted_set_redis(key)
    newrelic_begin_rescue { $redis_others.perform_redis_op("exists", key) }
  end

  def add_in_sorted_set_redis(key, score, member, expires = 86400)
    multi_actions_sorted_set_redis do |connection|
      connection.perform_redis_op("zadd", key, score, member)
      connection.perform_redis_op("expire", key, expires) if expires
    end
  end

  def multi_add_in_sorted_set_redis(key, value, expires = 86400)
    multi_actions_sorted_set_redis do |connection|
      connection.perform_redis_op("zadd", key, value)
      connection.perform_redis_op("expire", key, expires)
    end
  end

  def size_of_sorted_set_redis(key)
    newrelic_begin_rescue { $redis_others.perform_redis_op("zcard", key) }
  end

  def get_index_from_sorted_set_redis(key, member)
    newrelic_begin_rescue { $redis_others.perform_redis_op("zrank", key, member) }
  end

  def get_rank_from_sorted_set_redis(key, member)
    newrelic_begin_rescue { $redis_others.perform_redis_op("zrevrank", key, member) }
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

  def get_largest_members_of_sorted_set_redis(key, count = 1, start = 0)
    newrelic_begin_rescue { $redis_others.perform_redis_op("zrevrange", key, start, count - 1, {:withscores => true}) }
  end

  # piplined methods starts here
  def piplined_redis_action
    newrelic_begin_rescue do 
      return $redis_others.pipelined do 
          yield
        end
    end
  end

  def pipelined_size_of_sorted_set_redis(keys,category_list)
    size_array = piplined_redis_action do 
      category_list.each do |category|
        $redis_others.perform_redis_op('zcard',keys[category])
      end
    end
    process_piplined_result(size_array, category_list)
  end

  def pipelined_get_rank_from_sorted_set_redis(keys, member, category_list)
    rank_array = piplined_redis_action do 
      category_list.each do |category|
        $redis_others.perform_redis_op("zrevrank", keys[category], member)
      end
    end
    process_piplined_result(rank_array, category_list)
  end

  def pipelined_get_members_of_sorted_set_redis(keys, category_list, count, start)
    members_array = piplined_redis_action do
      category_list.each do |category|
        $redis_others.perform_redis_op("zrevrange", keys[category], start[category], count[category] - 1, { :withscores => true })
      end
    end
    process_piplined_result(members_array, category_list)
  end

  def pipelined_get_largest_member_of_sorted_set_redis(keys, category_list, count = 1, start = 0)
    largest_member_array = piplined_redis_action do
      category_list.each do |category|
        $redis_others.perform_redis_op("zrevrange", keys[category], start, count - 1, { :withscores => true })
      end
    end
    process_largest_result(largest_member_array, category_list)
  end

  def process_largest_result(result_array, category_list)
    result_hash = {}
    result_array.each_with_index do |result, index|
      result_hash[category_list[index]] ||= {}
      result_hash[category_list[index]][:largest] = result
    end
    result_hash
  end

  def process_piplined_result(result_array, category_list)
    result_hash = {}
    result_array.each_with_index do |result, index|
      result_hash[category_list[index]] = result
    end
    result_hash
  end
end
