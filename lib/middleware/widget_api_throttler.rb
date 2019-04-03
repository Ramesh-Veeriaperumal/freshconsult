class Middleware::WidgetApiThrottler < Middleware::FdApiThrottler
  include Redis::RedisKeys

  API_LIMIT = 500
  THROTTLE_PERIOD = 1.minute

  def correct_namespace?(path_info)
    CustomRequestStore.read(:widget_api_request)
  end

  def api_expiry
    THROTTLE_PERIOD
  end

  def api_limit
    @api_limit ||= begin
      api_limits = get_multiple_redis_keys(account_api_limit_key, default_api_limit_key) || []
      (api_limits[0] || api_limits[1] || API_LIMIT).to_i
    end
  end

  def key
    format(WIDGET_API_THROTTLER, account_id: account_id)
  end

  def account_api_limit_key
    format(ACCOUNT_WIDGET_API_LIMIT, account_id: account_id)
  end

  def default_api_limit_key
    DEFAULT_WIDGET_API_LIMIT
  end
end
