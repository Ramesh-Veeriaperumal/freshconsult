require 'securerandom'

# rubocop:disable Style/GlobalVars

module Redis::Redlock
  mattr_accessor :unlock_script_sha

  class << self
    def unlock_script
      <<-LUA
        if redis.call("get",KEYS[1]) == ARGV[1] then
            return redis.call("del",KEYS[1])
        else
            return 0
        end
      LUA
    end

    def load_unlock_lua_script_to_redis
      Rails.logger.info 'Loading unlock script'
      @@unlock_script_sha = $redlock.perform_redis_op('SCRIPT', :load, unlock_script) # rubocop:disable Style/ClassVars
    end
  end

  # returns true if the given block is executed without any exception, otherwise returns false.
  # if there are any exception in the given block, it will unlock and throw the exception.
  def acquire_lock_and_run(options)
    key = options[:key]
    random_value = unique_id

    retry_count = options[:retry_count] || 5
    retry_delay = options[:retry_delay] || 1000
    ttl = options[:ttl]

    begin
      # for equally distributed random delay, we can assume that, delay block will wait for (retry_count * (retry_delay/2))millis on average.At most this will wait for (retry_count * retry_delay) millis
      retry_count.times do
        if lock_key(key, random_value, ttl)
          yield
          return true
        else
          random_sleep(retry_delay)
        end
      end
    ensure
      unlock_key(key, random_value)
    end
    false
  end

  # methods to manually controll retry, sleep, unlock
  def acquire_lock(key, ttl)
    random_value = unique_id
    return random_value if lock_key(key, random_value, ttl)
  end

  def release_lock(key, random_value)
    unlock_key(key, random_value)
  end

  private

    def lock_key(key, value, ttl = 3000)
      return $redlock.client.call([:set, key, value, :nx, :px, ttl])
    rescue StandardError
      return false
    end

    def unlock_key(key, value)
      $redlock.evalsha(@@unlock_script_sha, [key], [value])
    rescue StandardError
      return false
    end

    def unique_id
      SecureRandom.uuid
    end

    def random_sleep(retry_delay)
      sleep(rand(retry_delay).to_f / 1000)
    end
end

# rubocop:enable Style/GlobalVars
