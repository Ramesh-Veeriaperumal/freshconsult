class Workers::Throttler
  extend Resque::AroundPerform
  extend Redis::RedisKeys
  extend Redis::OthersRedis

  @queue = 'throttler_worker'

  def self.perform throttler_args
    begin
      key             = throttler_args[:key]
      count           = get_others_redis_key(key).to_i
      expires_after   = get_others_redis_expiry(key)
      retry_after     = throttler_args[:retry_after].to_i
      retry_attempt   = throttler_args[:retry_after].present?
      limit_exceeded  = count >= throttler_args[:limit]

      if limit_exceeded || retry_attempt
        schedule_after  = limit_exceeded ? 
                          (expires_after > retry_after ? expires_after : retry_after) : retry_after
        throttler_args[:retry_after] = nil
        Resque.enqueue_in(schedule_after, Workers::Throttler, throttler_args)
      else
        args                   = throttler_args[:args]
        args[:current_user_id] = throttler_args[:current_user_id]
        worker                 = throttler_args[:worker].constantize
        increment_others_redis(key)
        set_others_redis_expiry key, throttler_args[:expire_after] if expires_after == -1
        Resque.enqueue(worker, args)
      end
    rescue Resque::DirtyExit
      Resque.enqueue(Workers::Throttler, throttler_args)
    rescue Exception => e
      puts "something is wrong  : #{e.message}"
    end
  end

end