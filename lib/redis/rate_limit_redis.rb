module Redis::RateLimitRedis
  include Fluffy::Constants

  def get_account_api_limit
    handle_exception { $rate_limit.perform_redis_op("get", account_api_limit_key) }
  end

  def set_account_api_limit(value)
    if value
      handle_exception { $rate_limit.perform_redis_op("set", account_api_limit_key, value) }
    else
      handle_exception { $rate_limit.perform_redis_op("del", account_api_limit_key) }
    end
  end

  def increment_redis(key, used)
    handle_exception { return $rate_limit.perform_redis_op("INCRBY", key, used) }
  end

  def get_redis_api_expiry(key)
    handle_exception { $rate_limit.perform_redis_op("ttl", key) }
  end

  def set_redis_expiry(key, expires)
    handle_exception { $rate_limit.perform_redis_op("expire", key, expires) }
  end

  def get_api_rate_limit(key)
    handle_exception { $rate_limit.perform_redis_op("get", key) }
  end

  def get_multiple_rate_limit_redis_keys(*keys)
    handle_exception { $rate_limit.perform_redis_op("mget", *keys) }
  end

  def get_api_limit_from_redis(account_id, plan_id)
    api_limits = get_multiple_rate_limit_redis_keys(account_api_limit_key(account_id), plan_api_limit_key(plan_id), default_api_limit_key) || []
    (api_limits[0] || api_limits[1] || api_limits[2] || Middleware::FdApiThrottler::API_LIMIT).to_i
  end

  def get_email_limit_from_redis(plan_id)
    overall_limit = get_others_redis_key(format(PLAN_EMAIL_LIMIT, plan_id: plan_id))
    unless overall_limit.nil? || overall_limit.to_i.zero?
      {
        "limit": overall_limit,
        "granularity": MINUTE_GRANULARITY,
        "account_paths": [
          JSON.parse(get_others_redis_hash_value(format(PLAN_EMAIL_PATHS_LIMIT, plan_id: plan_id), 'EMAIL_SERVICE') || '{}'),
          JSON.parse(get_others_redis_hash_value(format(PLAN_EMAIL_PATHS_LIMIT, plan_id: plan_id), 'EMAIL_SERVICE_SPAM') || '{}')
          ]
      }
    else
      {
        "limit": overall_limit || 400,
        "granularity": MINUTE_GRANULARITY
      }
    end
  end

  def get_api_min_limit_from_redis(plan_id)
    overall_limit = get_others_redis_key(format(PLAN_API_MIN_LIMIT, plan_id: plan_id))
    unless overall_limit.nil? || overall_limit.to_i == 0
      {
        "limit": overall_limit,
        "granularity": MINUTE_GRANULARITY,
        "account_paths": [
          JSON.parse(get_others_redis_hash_value(format(PLAN_API_MIN_PATHS_LIMIT, plan_id: plan_id), 'TICKETS_LIST') || '{}'),
          JSON.parse(get_others_redis_hash_value(format(PLAN_API_MIN_PATHS_LIMIT, plan_id: plan_id), 'CONTACTS_LIST') || '{}'),
          JSON.parse(get_others_redis_hash_value(format(PLAN_API_MIN_PATHS_LIMIT, plan_id: plan_id), 'CREATE_TICKET') || '{}'),
          JSON.parse(get_others_redis_hash_value(format(PLAN_API_MIN_PATHS_LIMIT, plan_id: plan_id), 'UPDATE_TICKET') || '{}')
        ]
      }
    else
      {
        "limit": overall_limit || 400,
        "granularity": MINUTE_GRANULARITY
      }
    end
  end

  def account_api_limit_key(account_id)
    format(ACCOUNT_API_LIMIT, account_id: account_id)
  end

  def plan_api_limit_key(plan_id)
    format(PLAN_API_LIMIT, plan_id: plan_id)
  end

  def default_api_limit_key
    DEFAULT_API_LIMIT
  end

  def plan_api_min_limit_key(plan_id)
    format(PLAN_API_MIN_LIMIT, plan_id: plan_id)
  end

  def handle_exception
      # similar to newrelic_begin_rescue, additionally logs and sends more info to newrelic.
      yield
    rescue Exception => e
      options_hash =  { uri: @request.env['REQUEST_URI'], custom_params: @request.env['action_dispatch.request_id'],
                        description: 'Error occurred while accessing Redis', request_method: @request.env['REQUEST_METHOD'],
                        request_body: @request.env['rack.input'].gets }
      Rails.logger.error("Redis Exception :: Host: #{@host}, Exception: #{e.message}\n#{e.class}\n#{e.backtrace.join("\n")}")
      NewRelic::Agent.notice_error(e, options_hash)
      return
  end
end