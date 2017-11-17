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
    payload[:status] = extract_status_and_error(payload)
    # Please inform devops when any change is made in the log_file_format
    # We need to make the corresponding change in sumologic(for indexing data) and in the recipe for UnityMedia (parsed application.log)
    log_file_format = "uuid=#{payload[:uuid]}, error=#{paylod[:error]}, ip=#{payload[:ip]}, a=#{payload[:account_id]}, u=#{payload[:user_id]}, s=#{payload[:shard_name]}, d=#{payload[:domain]}, url=#{payload[:url]}, path=#{payload[:path]}, c=#{payload[:controller]}, action=#{payload[:action]}, host=#{payload[:server_ip]}, status=#{payload[:status]}, format=#{payload[:format]}, db=#{payload[:db_runtime]}, view=#{payload[:view_runtime]}, duration=#{payload[:duration]}"
  end

  def log_file
    "#{Rails.root}/log/application.log"      
  end 
  
  def custom_logger(path)
    @@custom_logger ||= CustomLogger.new(path)
  end

  def extract_status_and_error(payload)
    if (status = payload[:status])
      status.to_i
    elsif (error = payload[:exception])
      exception, message = error
      payload[:error] = "#{exception}: #{message.present? ? message.truncate(200) : ''}"
      error_status_code(exception)
    else
      0
    end
  end

  def error_status_code(exception)
    # ActionDispatch::ExceptionWrapper.rescue_responses has a map as defined in :
    # https://github.com/rails/rails/blob/665ac7cff212d010a3573f85cea895666fbaad15/guides/source/configuring.md
    # Any exceptions that are not configured will be mapped to 500 Internal Server Error
    status = ActionDispatch::ExceptionWrapper.rescue_responses[exception]
    Rack::Utils.status_code(status)
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
