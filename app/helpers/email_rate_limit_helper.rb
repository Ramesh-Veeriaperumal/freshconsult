module EmailRateLimitHelper
  include Redis::RedisKeys

  def rate_limit_count_key(account_id, hour, quadrant)
    format(EMAIL_RATE_LIMIT_COUNT, account_id: account_id, hour_quadrant: hour.to_s + quadrant.to_s)
  end

  def rate_limit_breached_key(account_id)
    format(EMAIL_RATE_LIMIT_BREACHED, account_id: account_id)
  end
end
