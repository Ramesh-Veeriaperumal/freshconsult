module Redis::IntegrationsRedis
	def get_integ_redis_key key
		$redis_integrations.perform_redis_op("get", key)
	end

	def set_integ_redis_key(key, value, expires = 86400)
		$redis_integrations.perform_redis_op("set", key, value)
		$redis_integrations.perform_redis_op("expire", key, expires) if expires
	end

	def set_key(key, value, expires = 86400)
		$redis_integrations.perform_redis_op("set", key, value)
		$redis_integrations.perform_redis_op("expire", key, expires) if expires
	end

	def remove_integ_redis_key key
		$redis_integrations.perform_redis_op("del", key)
	end
	
	def get_key(key)
		$redis_integrations.perform_redis_op("get", key)
	end
	
	def remove_key(key)
		$redis_integrations.perform_redis_op("del", key)
	end
	
	def remove_from_set(key, values)
		newrelic_begin_rescue do
			if values.respond_to?(:each)
 				values.each do |val|
 					$redis_integrations.perform_redis_op("srem", key, val)
 				end
 			else
 				$redis_integrations.perform_redis_op("srem", key, values)
 			end
		end
	end
	
	def add_to_set(key, values, expires = 86400)
		result = false
 		newrelic_begin_rescue do
 			if values.respond_to?(:each)
				result = true
 				values.each do |val|
 					result &= $redis_integrations.perform_redis_op("sadd", key, val)
 				end
 			else
 				result = $redis_integrations.perform_redis_op("sadd", key, values)
 			end
 			# $redis.expire(key,expires) if expires
 	  	end
 	  	result
 	end

 	def integ_set_members(key)
		$redis_integrations.perform_redis_op("smembers", key)
	end

	def is_value_in_set? key, value
		newrelic_begin_rescue do
			return $redis_integrations.perform_redis_op("sismember", key, value)
		end
	end

	alias value_in_set? is_value_in_set?

	def remove_value_from_set(key, value)
		$redis_integrations.perform_redis_op("srem", key, value)
	end

	def publish_to_channel channel, message
		newrelic_begin_rescue do
	  		return $redis_integrations.perform_redis_op("publish", channel, message)
		end
	end
	
	def get_count_from_integ_redis_set(key)
		$redis_integrations.perform_redis_op("scard", key)
	end

	def incr_val(key)
		$redis_integrations.perform_redis_op("incr", key)
	end

end