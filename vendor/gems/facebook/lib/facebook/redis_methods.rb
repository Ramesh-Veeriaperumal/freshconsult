module Facebook::RedisMethods
  
  include Redis::OthersRedis
  include Redis::RedisKeys
  
  APP_RATE_LIMIT_EXPIRY  = 600
  API_HIT_COUNT_EXPIRY   = 3600
  USER_RATE_LIMIT_EXPIRY = 1800
  PAGE_RATE_LIMIT_EXPIRY = 1800
  
  #10 minutes expiry for APP RATE LIMITS
  def throttle_fb_feed_processing
    set_others_redis_key(FACEBOOK_APP_RATE_LIMIT, 1, APP_RATE_LIMIT_EXPIRY) unless app_rate_limit_reached?
  end
  
  def app_rate_limit_reached?
    redis_key_exists?(FACEBOOK_APP_RATE_LIMIT)
  end
  
  def user_api_rate_limit_reached?(page_id)
    redis_key_exists?(FACEBOOK_USER_RATE_LIMIT % {:page_id => page_id})
  end
  
  def page_rate_limit_reached?(account_id, page_id)
    redis_key_exists?(FACEBOOK_PAGE_RATE_LIMIT % {:account_id => account_id, :page_id => page_id})
  end

  def fb_api_hit_count(page_id)
    get_others_redis_key(FACEBOOK_USER_RATE_LIMIT % {:page_id => page_id})
  end
  
  #10 minutes expiry for APP RATE LIMITS
  def throttle_processing
    set_others_redis_key(FACEBOOK_APP_RATE_LIMIT, 1, APP_RATE_LIMIT_EXPIRY) 
  end
  
  #30 minutes expiry for PAGE RATE LIMITS
  def throttle_fb_page_processing(account_id, page_id)
    set_others_redis_key(FACEBOOK_PAGE_RATE_LIMIT % {:account_id => account_id, :page_id => page_id}, 1, PAGE_RATE_LIMIT_EXPIRY) unless page_rate_limit_reached?(account_id, page_id)
  end  

  #30 minutes expiry for USER RATE LIMITS
  def throttle_page_processing(page_id)
    set_others_redis_key(FACEBOOK_USER_RATE_LIMIT % {:page_id => page_id}, 1, USER_RATE_LIMIT_EXPIRY) unless user_api_rate_limit_reached?(page_id)
  end
  
  #API Count - 200 calls/user for an hour
  def increment_api_hit_count_to_redis(page_id)
    key   = FACEBOOK_API_HIT_COUNT % {:page_id => page_id}
    set_others_redis_expiry(key, API_HIT_COUNT_EXPIRY) if increment_others_redis(key) == 1
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
