class Middleware::PrivateApiThrottler < Middleware::FdApiThrottler
  include Redis::RedisKeys
  include Redis::RateLimitRedis

  API_CURRENT_VERSION = 'private-v1'.freeze
  THROTTLE_PERIOD = 1.minute.freeze
  API_LIMIT = 3000

  def initialize(app, options = {})
    super(app, options)
    @app = app
  end

  def correct_namespace?(path_info)
    CustomRequestStore.read(:private_api_request)
  end

  def api_expiry
    THROTTLE_PERIOD
  end

  def key
    format(PRIVATE_API_THROTTLER, account_id: account_id)
  end

  def api_limit
    @api_limit ||= begin
      api_limits = get_multiple_rate_limit_redis_keys(account_api_limit_key, default_api_limit_key) || []
      (api_limits[0] || api_limits[1] || API_LIMIT).to_i
    end
  end

  def extra_credits
    CustomRequestStore.store[:extra_credits] || 0
  end

  def default_api_limit_key
    DEFAULT_PRIVATE_API_LIMIT
  end

  def account_api_limit_key
    format(ACCOUNT_PRIVATE_API_LIMIT, account_id: account_id)
  end
end
