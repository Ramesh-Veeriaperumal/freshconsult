module Redis::PortalRedis
	def get_portal_redis_key key
		newrelic_begin_rescue { $redis_portal.get(key) }
	end

	def set_portal_redis_key(key, value, expires = 86400)
		newrelic_begin_rescue do
			$redis_portal.set(key, value)
			$redis_portal.expire(key,expires) if expires
	  end
	end

	def remove_portal_redis_key key
		newrelic_begin_rescue { $redis_portal.del(key) }
	end

	def increment_portal_redis_version(key)
		newrelic_begin_rescue { $redis_portal.INCR(key) }
	end

end