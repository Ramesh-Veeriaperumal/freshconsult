module Redis::ReportsRedis
	def get_reports_redis_key key
		newrelic_begin_rescue { $redis_reports.get(key) }
	end

	def set_reports_redis_key(key, value, expires = 86400)
		newrelic_begin_rescue do
			$redis_reports.set(key, value)
			$redis_reports.expire(key,expires) if expires
	  end
	end

	def remove_reports_redis_key key
		newrelic_begin_rescue { $redis_reports.del(key) }
	end

	def get_reports_hash_value(hash, key)
		newrelic_begin_rescue do
			$redis_reports.hget(hash, key)
	  end
	end

	def add_to_reports_hash(hash, key, value, expires = 86400)
		newrelic_begin_rescue do
			$redis_reports.hset(hash, key, value)
	  end
	end

	def add_to_reports_set(key, values, expires = 86400)
		newrelic_begin_rescue do
			if values.respond_to?(:each)
				values.each do |val|
					$redis_reports.sadd(key, val)
				end
			else
				$redis_reports.sadd(key, values)
			end
	  end
	end

	def set_reports_members(key)
		newrelic_begin_rescue { $redis_reports.smembers(key) }
	end

	def remove_reports_member(key, value)
		newrelic_begin_rescue { $redis_reports.srem(key, value) }
	end

end