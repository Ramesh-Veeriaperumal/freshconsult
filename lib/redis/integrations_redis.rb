module Redis::IntegrationsRedis
	def get_integ_redis_key key
		newrelic_begin_rescue { $redis_integrations.get(key) }
	end

	def set_integ_redis_key(key, value, expires = 86400)
		newrelic_begin_rescue do
			$redis_integrations.set(key, value)
			$redis_integrations.expire(key,expires) if expires
	  end
	end

	def remove_integ_redis_key key
		newrelic_begin_rescue { $redis_integrations.del(key) }
	end

end