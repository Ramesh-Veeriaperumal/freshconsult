module Redis::TicketsRedis
	def get_tickets_redis_key key
		newrelic_begin_rescue { $redis_tickets.get(key) }
	end

	def set_tickets_redis_key(key, value, expires = 86400)
		newrelic_begin_rescue do
			$redis_tickets.set(key, value)
			$redis_tickets.expire(key,expires) if expires
	  end
	end

	def remove_tickets_redis_key key
		newrelic_begin_rescue { $redis_tickets.del(key) }
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