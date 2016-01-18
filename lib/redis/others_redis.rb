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
		newrelic_begin_rescue { return $redis_others.INCR(key) }
	end

	def decrement_others_redis(key, value=1)
		newrelic_begin_rescue do
			if value == 1
				$redis_others.DECR(key)
			else
				$redis_others.DECRBY(key, value)
			end
		end
	end

	def redis_key_exists?(key)
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
	
	def ismember?(key, value)
		newrelic_begin_rescue { $redis_others.sismember(key, value) }
	end
	
	def set_others_redis_hash(key, value)
		newrelic_begin_rescue { $redis_others.mapped_hmset(key,value) }
	end

	def get_others_redis_hash(key)
		newrelic_begin_rescue { $redis_others.hgetall(key) }
	end
  
  def add_member_to_redis_set(key, member)
    newrelic_begin_rescue { $redis_others.sadd(key, member) }
  end

  def remove_member_from_redis_set(key, member)
    newrelic_begin_rescue { $redis_others.srem(key, member) }
  end
  
  def get_all_members_in_a_redis_set(key)
    newrelic_begin_rescue { $redis_others.smembers(key) }
  end
end
