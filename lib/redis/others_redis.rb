module Redis::OthersRedis
	def get_others_redis_key key
		newrelic_begin_rescue { $redis_others.get(key) }
	end

	def set_others_redis_key(key, value, expires = 86400)
		newrelic_begin_rescue do
			$redis_others.set(key, value)
			$redis_others.expire(key,expires) if expires
	  end
	end

	def remove_others_redis_key key
		newrelic_begin_rescue { $redis_others.del(key) }
	end

	def set_others_redis_expiry(key, expires)
		newrelic_begin_rescue do
			$redis_others.expire(key, expires)
		end
	end

	def get_others_redis_expiry(key)
		newrelic_begin_rescue { $redis_others.ttl(key) }
	end

	def increment_others_redis(key)
		newrelic_begin_rescue { $redis_others.INCR(key) }
	end
end