# frozen_string_literal: true

module TenantRateLimiter
  module Iterable
    module RedisHelperMethods
      def get_expiry(key)
        newrelic_redis_begin_rescue { $redis_others.ttl(key) }
      end

      def jobs_count(conn, key)
        conn.zcard(key)
      end

      def redis_connection_pool
        newrelic_redis_begin_rescue do
          @redis_pool.with do |conn|
            yield(conn)
          end
        end
      end

      def newrelic_redis_begin_rescue
        yield
      rescue Redis::BaseError => e
        Rails.logger.error "Redis Error, #{e.message}"
        NewRelic::Agent.notice_error(e)
      end
    end
  end
end
