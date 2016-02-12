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
  
  def update_like_in_redis(field_key, like)
    newrelic_begin_rescue do
      $redis_others.hincrby(FACEBOOK_LIKES, field_key, like)
    end
  end
  
  def process_likes_from_redis
    newrelic_begin_rescue do
      likes, del_status = $redis_others.multi do |multi|
        multi.hgetall(FACEBOOK_LIKES)
        multi.del(FACEBOOK_LIKES)
      end
      Social::Dynamo::Facebook.new.update_likes_in_dynamo(likes) if del_status
    end
  end
  
end
