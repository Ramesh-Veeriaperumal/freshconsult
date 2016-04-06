module Redis::PortalRedis
	def get_portal_redis_key key
		$redis_portal.perform_redis_op("get", key)
	end

	def set_portal_redis_key(key, value, expires = 7776000)
		$redis_portal.perform_redis_op("set", key, value)
		$redis_portal.perform_redis_op("expire", key, expires) if expires
	end

	def remove_portal_redis_key key
		$redis_portal.perform_redis_op("del", key)
	end

	def increment_portal_redis_version(key)
		$redis_portal.perform_redis_op("INCR", key)
	end

end