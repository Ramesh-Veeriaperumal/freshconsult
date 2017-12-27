namespace :redis_maintenance do
  
  desc "Set timestamp every 5min for reference in Redis AOF"
  task :set_timestamp => :environment do
    REDIS_UNIQUE_CONNECTION_OBJECTS.each do |con|
      con.perform_redis_op("set", Redis::RedisKeys::TIMESTAMP_REFERENCE, Time.now.to_i)
    end
  end

  desc "Send weekly slowlog mail to the team"
  task :slowlog_mailer => :environment do
  	slowlog = []
    REDIS_UNIQUE_CONNECTION_OBJECTS.each do |con|      
      # Move to Lua script.
      # Config response format => ["slowlog-max-len", "128"]
      len = con.perform_redis_op("config", "get", "slowlog-max-len")
      result = con.multi do |m|
        m.perform_redis_op("slowlog", "get", len[1])
        m.perform_redis_op("slowlog", "reset")
      end
      slowlog = slowlog + result[0]
    end
  	if slowlog.any?
  		csv = Redis::SlowlogParser.parse(slowlog)
  	end
	  FreshopsMailer.send_redis_slowlog(csv)
  end

end