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

	def set_others_redis_with_expiry(key, value, options)
		newrelic_begin_rescue { $redis_others.set(key, value, options) }
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

	def exists?(key)
		newrelic_begin_rescue { $redis_others.exists(key) }
	end

  	def publish_to_channel channel, message
    	newrelic_begin_rescue do
        	return $redis_others.publish(channel, message)
    	end
 	end

  	def get_others_redis_list(key, start = 0, stop = -1)
		newrelic_begin_rescue { $redis_others.lrange(key,start,stop) }
	end

	def get_others_redis_llen(key)
		newrelic_begin_rescue { $redis_others.llen(key) }
	end

	def set_others_redis_lpush(key, value)
		newrelic_begin_rescue { $redis_others.lpush(key,value) }
	end

	def get_others_redis_rpoplpush(source, destination)
		newrelic_begin_rescue { $redis_others.rpoplpush(source, destination) }
	end

	def get_others_redis_lrem(key, value, all=0)
		newrelic_begin_rescue { $redis_others.lrem(key,all,value) }
	end
end
