module APIThrottlerMethods
  include MemcacheKeys
  include Redis::OthersRedis
  include Redis::RedisKeys

  def allowed_api_limit
    api_key = API_LIMIT % {:account_id => current_account.id}
    api_limit = MemcacheKeys.fetch(api_key) do
      current_account.api_limit.to_i
    end
  end

  def spent_api_limit
    key = API_THROTTLER % {:host => env["HTTP_HOST"]}
    count = get_others_redis_key(key).to_i
  end
end