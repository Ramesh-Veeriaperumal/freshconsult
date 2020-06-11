module Redis::SilkroadRedis
  def get_inactive_silkroad_features(key)
    $redis_others.perform_redis_op('lrange', key, 0, -1)
  end
end
