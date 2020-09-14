module Redis::TicketsRedis
	def get_tickets_redis_key key
		newrelic_begin_rescue { $redis_tickets.perform_redis_op("get", key) }
	end

  def get_tickets_redis_hash_key key
    newrelic_begin_rescue { $redis_tickets.perform_redis_op("hgetall", key) }
  end

  def redis_key_type key
    #returns: (String) — string, list, set, zset, hash or none
    newrelic_begin_rescue { $redis_tickets.perform_redis_op("type", key) }
  end

	def tickets_redis_list(key, start = 0, stop = -1)
		newrelic_begin_rescue { $redis_tickets.perform_redis_op("lrange", key, start, stop) }
	end

	def set_tickets_redis_lpush(key, value)
		newrelic_begin_rescue { $redis_tickets.perform_redis_op("lpush", key, value) }
	end


	def set_tickets_redis_key(key, value, expires = 86400)
		newrelic_begin_rescue do
			$redis_tickets.perform_redis_op("set", key, value)
			$redis_tickets.perform_redis_op("expire", key, expires) if expires
	  end
	end


  def set_tickets_redis_hash_key(key, value, expires = 86400)
    newrelic_begin_rescue do
      $redis_tickets.perform_redis_op("hmset", key, value.flatten) #value for hmset- Array<String> ["key1","val1","key2","val2"]
      $redis_tickets.perform_redis_op("expire", key, expires) if expires
    end
  end

	def remove_tickets_redis_key key
		newrelic_begin_rescue { $redis_tickets.perform_redis_op("del", key) }
	end

	def key_exists? key
		newrelic_begin_rescue { $redis_tickets.perform_redis_op("exists", key) }
	end

  def increment_tickets_redis_key key, value = 1
    newrelic_begin_rescue { $redis_tickets.perform_redis_op("INCRBY", key, value) }
  end

	def tickets_list_push(key,values,direction = 'right', expires = 3600)
			command = direction == 'right' ? 'rpush' : 'lpush'
			unless values.is_a?(Array)
				$redis_tickets.perform_redis_op(command, key, values)
			else
				values.each do |val|
					$redis_tickets.perform_redis_op(command, key, val)
				end
			end
			$redis_tickets.perform_redis_op("expire", key, expires) if expires
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      return
	end

	def ticket_list_members(key)
		count = 0
    tries = 3
    begin
			length = $redis_tickets.perform_redis_op("llen", key)
			$redis_tickets.perform_redis_op("lrange", key, 0, length - 1)
	  rescue Exception => e
	  	NewRelic::Agent.notice_error(e,{:key => key, 
        :value => length,
        :description => "Redis issue",
        :count => count})
      if count<tries
          count += 1
          retry
      end
	  end
	end
end
