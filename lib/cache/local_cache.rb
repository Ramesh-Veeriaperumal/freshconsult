module Cache
  module LocalCache
    include Redis::RedisKeys
    include Redis::OthersRedis

    WEBHOOK_BLACKLIST_IP = 'WEBHOOK_BLACKLIST_IP'.freeze
    WEBHOOK_BLACKLIST_DOMAIN = 'WEBHOOK_BLACKLIST_DOMAIN'.freeze

    LOCAL_CACHE_PREFIX = 'LC:'.freeze

    def fetch_lcached_set(key, expiry)
      fetch_lcached('smembers', key, expiry) || []
    end

    def fetch_lcached_hash(key, expiry)
      fetch_lcached('hgetall', key, expiry) || []
    end

    def clear_lcached(key)
      l_key = lookup_key(key)
      Rails.cache.delete(l_key)
    end

    private

      def fetch_lcached(operation, key, expiry = 30.mins)
        l_key = lookup_key(key)
        Rails.cache.fetch(l_key, race_condition_ttl: 10.seconds, expires_in: expiry.to_i) do
          Rails.logger.debug("Fetching #{l_key} from redis")
          $redis_others.perform_redis_op(operation, key)
        end
      end

      def lookup_key(key)
        "#{LOCAL_CACHE_PREFIX}#{key}"
      end
  end
end
