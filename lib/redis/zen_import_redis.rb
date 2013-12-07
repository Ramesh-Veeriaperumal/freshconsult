module Redis::ZenImportRedis

	def remove_zen_import_redis_key key
		newrelic_begin_rescue { $redis_others.del(key) }
	end

	def get_zen_import_hash_value(hash, key)
		newrelic_begin_rescue { $redis_others.hget(hash, key) }
	end

	def add_to_zen_import_hash(hash, key, value)
		newrelic_begin_rescue { $redis_others.hset(hash, key, value) }
	end

	def incr_queue_count_hash(hash, key, value = 1)
		newrelic_begin_rescue { $redis_others.hincrby(hash, key, value) }
	end

	def get_full_hash(hash)
		newrelic_begin_rescue { $redis_others.hgetall(hash) }
	end

end
