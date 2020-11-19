# frozen_string_literal: true

module TenantRateLimiter
  module Iterable
    module Constants
      RETRY_DURATION = [300, 900, 3_600, 14_400, 36_000].freeze
      REDIS_BATCH_SIZE = 5

      NAMESPACE_ACCOUNTS_SET_KEY = '%{namespace}:TENANT_RATE_LIMITER:ACCOUNTS_SET'.freeze
      TENANT_RATE_LIMIT_KEY = 'TENANT_RATE_LIMIT:%{type}:%{tenant_id}'.freeze

      ENQUEUE_SCRIPT = <<-LUA
        local account_webhook_jobs_key = KEYS[1]
        local accounts_set_key = KEYS[2]

        local jobs_size = redis.call('zcard', account_webhook_jobs_key)

        if jobs_size < tonumber(ARGV[4]) then
          redis.call('zadd', account_webhook_jobs_key, ARGV[2], ARGV[3])
        else
          -- Log job dropping and proceed
          return 2
        end

        return redis.call('sadd', accounts_set_key, ARGV[1])
         -- Sidekiq job has to be enqueued if this returns 1 and no action to be taken if this returns 0. The above method returns 0 if the member already exists in the set and 1 if the member was added now.
      LUA

      DEQUEUE_SCRIPT = <<-LUA
        local account_webhook_jobs_key = KEYS[1]
        local accounts_set_key = KEYS[2]
        local batch_size = tonumber(ARGV[2])
        local jobs_size = redis.call('zcard', account_webhook_jobs_key)
        local jobs = redis.call('zrangebyscore', account_webhook_jobs_key, '-inf', ARGV[1], "LIMIT", 0, batch_size)

        if jobs_size > batch_size then
          redis.call('zrem', account_webhook_jobs_key, unpack(jobs))
        else
          redis.call('zremrangebyscore', account_webhook_jobs_key, '-inf', ARGV[1])
          redis.call('srem', accounts_set_key, ARGV[3])
        end

        return {jobs, jobs_size > batch_size}
      LUA

      CHECK_EXIT_SCRIPT = <<-LUA
        local account_webhook_jobs_key = KEYS[1]
        local accounts_set_key = KEYS[2]
        local jobs_size = redis.call('zcard', account_webhook_jobs_key)

        if jobs_size == 0 then
          redis.call('srem', accounts_set_key, ARGV[1])
        end

        return jobs_size
      LUA

      LUA_SCRIPTS = {
        enqueue: ENQUEUE_SCRIPT,
        dequeue: DEQUEUE_SCRIPT,
        check_exit: CHECK_EXIT_SCRIPT
      }.freeze

      RATE_LIMIT_SCRIPT = <<-LUA # Invoked in fetch_jobs method :: If this is the first batch of jobs being processed during the hour, we will set the expiry for the key.
        local current_count = redis.call('get', KEYS[1]) or 0
        local batch_size = tonumber(ARGV[1])
        local rate_limit = tonumber(ARGV[2])
        if ((tonumber(current_count) + batch_size) > rate_limit) then
          batch_size = rate_limit - current_count
        end
        if batch_size > 0 then
          local count = tonumber(redis.call('incrby', KEYS[1], batch_size))
          if count == batch_size then
            redis.call('expire', KEYS[1], 3600)
            return { batch_size, true }
          end
          return { batch_size, false }
        end
        return { 0, false }
      LUA

      SHA = {}
    end
  end
end
