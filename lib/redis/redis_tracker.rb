module Redis::RedisTracker
  MAX_CALL_THRESHOLD = 4
  MAX_DUP_CALLS = 2
  LOG_DELIMITER = "\n" + ('*' * 75) + "\n"

  def track_redis_calls(operator, *args)
    return if current_redis_tracker.nil? # making sure only web requests are tracked
    if operator == 'send'
      op = args[0]
      access_key = args[1]
    else
      op = operator
      access_key = args[0]
    end
    lookup_key = "#{op}|#{access_key}"
    tracker = current_redis_tracker
    tracker[lookup_key] = tracker[lookup_key].to_i + 1
    update_redis_tracker tracker
  rescue Exception => e
    Rails.logger.error("Error in redis tracker #{e.message}")
    NewRelic::Agent.notice_error(e)
  end

  def init_redis_tracker
    Thread.current[:access_tracker] = {} # init from middleware
  end

  def current_redis_tracker
    Thread.current[:access_tracker]
  end

  def log_redis_stats(req_path)
    tracker = current_redis_tracker
    stats_log = []
    tracker.each do |key, value|
      if value.to_i >= MAX_DUP_CALLS
        stats_log << "WARNING!! Redis action [#{key}] was done [#{value}] times - [#{req_path}]"
      end
    end
    call_count = total_redis_calls
    if call_count > MAX_CALL_THRESHOLD
      stats_log << "Total redis calls for [#{req_path}] was [#{call_count}]"
    end
    log_this(stats_log.join("\n")) if stats_log.present?
  rescue Exception => e
    Rails.logger.error("Error in redis tracker #{e.message}")
    NewRelic::Agent.notice_error(e)
  end

  private

    def redis_tracker_logger
      @@r_tracker_logger ||= Logger.new("#{Rails.root}/log/redis_tracker.log")
    end

    def update_redis_tracker(tracker)
      Thread.current[:access_tracker] = tracker
    end

    def log_this(message)
      message_with_delimiter = LOG_DELIMITER + message + LOG_DELIMITER
      Rails.logger.debug(message_with_delimiter)
      redis_tracker_logger.debug(message)
    end

    def total_redis_calls
      current_redis_tracker.values.map(&:to_i).reduce(:+).to_i
    end
end
