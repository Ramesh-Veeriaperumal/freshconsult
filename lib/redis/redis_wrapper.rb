# Use this wrapper method to perform operations on redis
# Usage:
#  $redis_tickets.perform_redis_op(operator, *args)
#  EX: $redis_tickets.perform_redis_op('set', key, value)
#  	   $redis_tickets.perform_redis_op('lrange', list, start_range, end_range)

module Redis::RedisWrapper

	Redis.class_eval do
	  def perform_redis_op(operator, *args)
	    self.send(operator, *args)
	  rescue Redis::BaseError => e
	    NewRelic::Agent.notice_error(e)
	  end
	end

end