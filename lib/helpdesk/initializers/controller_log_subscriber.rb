class ControllerLogSubscriber <  ActiveSupport::LogSubscriber
  
  # http://www.paperplanes.de/2012/3/14/on-notifications-logsubscribers-and-bringing-sanity-to-rails-logging.html

  def process_action(event)
    event.payload[:duration] = event.duration
    log_details(event.payload)
    track_controller_events(event.payload)
  end

  def log_details(payload)
    begin
      log_format = logging_format(payload)
      controller_logger = custom_logger(log_file)
      controller_logger.info "#{log_format}"
    rescue Exception => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Error occoured while capturing controller logs for #{path}"}})
    end
  end

  def logging_format(payload)
    payload[:db_runtime] = payload[:db_runtime].round(2) if payload[:db_runtime]
    payload[:view_runtime] = payload[:view_runtime].round(2) if payload[:view_runtime]
    payload[:duration] = payload[:duration].round(2)
    log_file_format = "ip=#{payload[:ip]}, a=#{payload[:account_id]}, u=#{payload[:user_id]}, s=#{payload[:shard_name]}, d=#{payload[:domain]}, url=#{payload[:url]}, path=#{payload[:path]}, controller=#{payload[:controller]}, action=#{payload[:action]}, host=#{payload[:server_ip]}, status=#{payload[:status]}, format=#{payload[:format]}, db=#{payload[:db_runtime]}, view=#{payload[:view_runtime]}, duration=#{payload[:duration]}"
  end

  def log_file
    "#{Rails.root}/log/application.log"      
  end 
  
  def custom_logger(path)
    @@custom_logger ||= CustomLogger.new(path)
  end

  def track_controller_events(payload)
    if TRACKED_RESPONSE_TIME.has_key?(payload[:controller]) && TRACKED_RESPONSE_TIME[payload[:controller]].include?(payload[:action].to_sym)
      statsd_timing(payload[:shard_name],"ticket_#{payload[:action]}_time",payload[:duration].round)
    end
    if TRACKED_CONTROLLERS.has_key?(payload[:controller]) && TRACKED_CONTROLLERS[payload[:controller]] == (payload[:action].to_sym)
      statsd_increment(payload[:shard_name],"#{payload[:controller].demodulize}_#{payload[:action]}_counter")
    end 
  end
end

ControllerLogSubscriber.attach_to :action_controller
