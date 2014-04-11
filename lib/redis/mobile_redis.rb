module Redis::MobileRedis
	def publish_to_channel channel, message
      newrelic_begin_rescue do
          return $redis_mobile.publish(channel, message)
      end
  end	
end