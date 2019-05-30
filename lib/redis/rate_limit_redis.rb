module Redis::RateLimitRedis

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

  def get_multiple_redis_keys(*keys)
    handle_exception { $rate_limit.perform_redis_op("mget", *keys) }
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