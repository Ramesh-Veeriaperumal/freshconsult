# frozen_string_literal: true

module CentralLib::CentralResyncRateLimiter
  include Redis::RedisKeys
  include Redis::OthersRedis
  include CentralLib::CentralResyncConstants

  def resync_worker_limit_reached?(source)
    # This will check whether the allowed worker limit reached for a source
    # return true if limit reached else increament the worker count and return false
    # to avoid race conditions on checking the key and incrementing in different operations
    Redis::LuaStore.evaluate(
      $redis_others,
      Redis::ResyncRatelimitterLua.resync_ratelimitter_lua_script,
      Redis::ResyncRatelimitterLua.resync_ratelimiter_lua,
      [resync_rate_limiter_key(source)], [resync_worker_limit_per_consumer]
    ) == 'true'
  end

  def resync_ratelimit_options(args)
    {
      batch_size: RESYNC_ENTITY_BATCH_SIZE,
      conditions: args[:conditions]
    }.tap { |hash_body| hash_body[:start] = args[:primary_key_offset] if args[:primary_key_offset].present? }
  end

  def max_allowed_records
    @max_allowed_records ||= (get_others_redis_key(CENTRAL_RESYNC_MAX_ALLOWED_RECORDS)&.to_i || RESYNC_MAX_ALLOWED_RECORDS)
  end

  def decrement_redis_key_on_job_end(source)
    decrement_others_redis(resync_rate_limiter_key(source))
  end

  private

    def resync_worker_limit_per_consumer
      resync_worker_limit = get_others_redis_key(CENTRAL_RESYNC_MAX_ALLOWED_WORKERS)
      resync_worker_limit&.to_i || RESYNC_WORKER_LIMIT
    end

    def resync_rate_limiter_key(source)
      format(CENTRAL_RESYNC_RATE_LIMIT, source: source)
    end
end
