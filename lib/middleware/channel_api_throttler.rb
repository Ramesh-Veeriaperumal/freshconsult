class Middleware::ChannelApiThrottler < Middleware::FdApiThrottler
  include Redis::RedisKeys

  API_LIMIT = 4000
  THROTTLE_PERIOD = 1.minute

  def correct_namespace?(path_info)
    CustomRequestStore.read(:channel_api_request) || CustomRequestStore.read(:channel_v1_api_request)
  end

  def api_expiry
    THROTTLE_PERIOD
  end

  def api_limit
    @api_limit ||= begin
      api_limits = get_multiple_rate_limit_redis_keys(account_api_limit_key, default_api_limit_key) || []
      (api_limits[0] || api_limits[1] || API_LIMIT).to_i
    end
   end

  def key
    format(CHANNEL_API_THROTTLER, account_id: account_id)
  end

  def account_api_limit_key
    format(ACCOUNT_CHANNEL_API_LIMIT, account_id: account_id)
  end

  def default_api_limit_key
    DEFAULT_CHANNEL_API_LIMIT
  end

  def is_fluffy_enabled?
    @request.env['HTTP_X_FW_RATELIMITING_MANAGED'] == "true"
  end
end
