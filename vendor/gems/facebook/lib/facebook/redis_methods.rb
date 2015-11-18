module Facebook::RedisMethods
  
  include Redis::OthersRedis
  include Redis::RedisKeys
  
  APP_RATE_LIMIT_EXPIRY = 900
  
  #10 minutes expiry for APP RATE LIMITS
  def throttle_fb_feed_processing
    set_others_redis_key(FACEBOOK_APP_RATE_LIMIT, 1, APP_RATE_LIMIT_EXPIRY) unless app_rate_limit_reached?
  end
  
  def app_rate_limit_reached?
    redis_key_exists?(FACEBOOK_APP_RATE_LIMIT)
  end
  
end
