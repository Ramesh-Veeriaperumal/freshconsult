class Throttler::BaseWorker
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Sidekiq::Worker

  attr_accessor :throttle_duration, :worker
  
  class ThrottlerKeyNotDefinedError < StandardError
  end

  class ThrottleLimitNotDefinedError < StandardError
  end
  
  def perform throttler_args
    throttler_args.symbolize_keys!
    throttler_key = key(throttler_args)
    throttle_count = get_others_redis_key(throttler_key).to_i
    throttle_expiration = get_others_redis_expiry(throttler_key)
    retry_after = throttler_args[:retry_after].to_i
    limit_exceeded = throttle_count >= throttle_limit
    if limit_exceeded || throttler_args[:retry_after].present?
      limit_exceeded_callback(throttle_expiration, throttler_args) if limit_exceeded
      schedule_after  = limit_exceeded ? 
                        ((throttle_expiration > retry_after) ? 
                          throttle_expiration 
                          : retry_after) 
                        : retry_after
      throttler_args[:retry_after] = nil
      self.class.name.constantize.perform_in(
        schedule_after, 
        throttler_args
      )
    else
      args = throttler_args[:args]
      increment_others_redis(throttler_key)
      if throttle_expiration < 0
        set_others_redis_expiry throttler_key, @throttle_duration 
      end
      @worker.perform_async(args)
    end
  rescue => e
    NewRelic::Agent.notice_error(e, {
      :custom_params => {
        :description =>"Sidekiq Throttler execution error"
      }})
  end

  protected
    def throttle_limit
      raise ThrottleLimitNotDefinedError, "Throttle limit not given"
    end

    def key(args)
      raise ThrottlerKeyNotDefinedError, "No Throttler Key defined"
    end

    def limit_exceeded_callback(throttle_expiration, throttler_args)
    end
end
