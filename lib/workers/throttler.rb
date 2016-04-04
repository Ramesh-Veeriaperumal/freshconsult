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
      Rails.logger.debug "Key: #{key}, Count: #{count}, Ttl: #{expires_after} "

      if limit_exceeded || retry_attempt
        schedule_after  = limit_exceeded ? 
                          (expires_after > retry_after ? expires_after : retry_after) : retry_after
        throttler_args[:retry_after] = nil
        Rails.logger.debug "Scheduling in #{schedule_after} seconds, Conditions: #{limit_exceeded}, #{retry_attempt}"
        Resque.enqueue_in(schedule_after, Workers::Throttler, throttler_args) #unless Rails.env.test?
      else
        args                   = throttler_args[:args]
        args[:current_user_id] = throttler_args[:current_user_id]
        args[:account_id]      = throttler_args[:account_id]
        worker                 = throttler_args[:worker].constantize
        count = increment_others_redis(key)
        if expires_after == -1
          set_others_redis_expiry key, throttler_args[:expire_after] 
          Rails.logger.debug "Expiry set in #{throttler_args[:expire_after]} seconds"
        end
        Rails.logger.debug "Enqueueing #{worker} NewCount: #{count}"
        Resque.enqueue(worker, args) #unless Rails.env.test?
      end
    rescue Resque::DirtyExit
      Resque.enqueue(Workers::Throttler, throttler_args)
    rescue Exception => e
      puts "something is wrong  Throttler : #{e.message}"
    end
  end

  def self.around_perform_with_shard(*args)
    args[0].is_a?(Hash) ? args[0].symbolize_keys! : args[1].symbolize_keys!
    yield
  end

end