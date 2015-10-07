module Redis::TicketsRedis
	def get_tickets_redis_key key
		newrelic_begin_rescue { $redis_tickets.get(key) }
	end

  def get_tickets_redis_hash_key key
    #TBD: Remove if condition after 2 days of deploying "save emails in ticket draft" enhancement
    #newrelic_begin_rescue { $redis_tickets.hgetall(key) } #Only this line is required
    newrelic_begin_rescue do
      key_type = redis_key_type(key)
      if key_type.eql? "string"
        draft_hash_data = {
          "draft_data" => get_tickets_redis_key(key),
          "draft_cc" => "",
          "draft_bcc" => ""
        }
        remove_tickets_redis_key(key)
        set_tickets_redis_hash_key(key, draft_hash_data)
      end
    end
    newrelic_begin_rescue { $redis_tickets.hgetall(key) }
  end

  def redis_key_type key
    #returns: (String) — string, list, set, zset, hash or none
    newrelic_begin_rescue { $redis_tickets.type(key) }
  end

	def tickets_redis_list(key, start = 0, stop = -1)
		newrelic_begin_rescue { $redis_tickets.lrange(key,start,stop) }
	end

	def set_tickets_redis_lpush(key, value)
		newrelic_begin_rescue { $redis_tickets.lpush(key,value) }
	end


	def set_tickets_redis_key(key, value, expires = 86400)
		newrelic_begin_rescue do
			$redis_tickets.set(key, value)
			$redis_tickets.expire(key,expires) if expires
	  end
	end


  def set_tickets_redis_hash_key(key, value, expires = 86400)
    newrelic_begin_rescue do
      $redis_tickets.hmset(key, value.flatten) #value for hmset- Array<String> ["key1","val1","key2","val2"]
      $redis_tickets.expire(key,expires) if expires
    end
  end

	def remove_tickets_redis_key key
		newrelic_begin_rescue { $redis_tickets.del(key) }
	end

	def key_exists? key
		newrelic_begin_rescue { $redis_tickets.exists(key) }
	end

  def increment_tickets_redis_key key, value = 1
    newrelic_begin_rescue { $redis_tickets.INCRBY(key, value) }
  end

	def tickets_list_push(key,values,direction = 'right', expires = 3600)
			command = direction == 'right' ? 'rpush' : 'lpush'
			unless values.is_a?(Array)
				$redis_tickets.send(command, key, values)
			else
				values.each do |val|
					$redis_tickets.send(command, key, val)
				end
			end
			$redis_tickets.expire(key,expires) if expires
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      return
	end

	def ticket_list_members(key)
		count = 0
    tries = 3
    begin
			length = $redis_tickets.llen(key)
			$redis_tickets.lrange(key,0,length - 1)
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

	def publish_to_tickets_channel channel, message
		newrelic_begin_rescue do
	  	return $redis_tickets.publish(channel, message)
	  end
	end

end