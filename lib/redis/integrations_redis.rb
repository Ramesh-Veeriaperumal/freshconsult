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

	def set_key(key, value, expires = 86400)
		newrelic_begin_rescue do
			$redis_integrations.set(key, value)
			$redis_integrations.expire(key,expires) if expires
	  end
	end

	def remove_integ_redis_key key
		newrelic_begin_rescue { $redis_integrations.del(key) }
	end
	
	def get_key(key)
		newrelic_begin_rescue { $redis_integrations.get(key) }
	end
	
	def remove_key(key)
		newrelic_begin_rescue { $redis_integrations.del(key) }
	end
	
	def remove_from_set(key, values)
		newrelic_begin_rescue do
			if values.respond_to?(:each)
 				values.each do |val|
 					$redis_integrations.srem(key, val)
 				end
 			else
 				$redis_integrations.srem(key, values)
 			end
		end
	end
	
	def add_to_set(key, values, expires = 86400)
		result = false
 		newrelic_begin_rescue do
 			if values.respond_to?(:each)
				result = true
 				values.each do |val|
 					result &= $redis_integrations.sadd(key, val)
 				end
 			else
 				result = $redis_integrations.sadd(key, values)
 			end
 			# $redis.expire(key,expires) if expires
 	  end
 	  result
 	end

 	def integ_set_members(key)
		newrelic_begin_rescue { $redis_integrations.smembers(key) }
	end

	def is_value_in_set? key, value
		newrelic_begin_rescue { return $redis_integrations.sismember(key, value) }
	end

	def remove_value_from_set(key, value)
		newrelic_begin_rescue { $redis_integrations.srem(key, value) }
	end

	def publish_to_channel channel, message
		newrelic_begin_rescue do
	  	return $redis_integrations.publish(channel, message)
	  end
	end
	
	def get_count_from_integ_redis_set(key)
		newrelic_begin_rescue { $redis_integrations.scard(key) }
	end

end