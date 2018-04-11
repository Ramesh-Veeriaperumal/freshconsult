class ControllerLogSubscriber <  ActiveSupport::LogSubscriber
  include LogHelper
  # http://www.paperplanes.de/2012/3/14/on-notifications-logsubscribers-and-bringing-sanity-to-rails-logging.html

  def process_action(event)
    event.payload[:duration] = event.duration
    log_details(event.payload)
    track_controller_events(event.payload)
  end

  def log_details(payload)
    begin
      log_format = logging_format(payload)
      if ENV['MIDDLEWARE_LOG_ENABLE'] == 'true'
        store_log_data(payload)
      else
        controller_logger = custom_logger(log_file)
        controller_logger.info "#{log_format}"
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Error occoured while capturing controller logs for #{payload[:path]}"}})
    end
  end

  def logging_format(payload)
    payload[:db_runtime] = payload[:db_runtime].round(2) if payload[:db_runtime]
    payload[:view_runtime] = payload[:view_runtime].round(2) if payload[:view_runtime]
    payload[:duration] = payload[:duration].round(2)
    payload[:status] = extract_status(payload)
    payload[:error] = extract_error(payload) if payload[:exception]
    log_format(payload)
  end

  def log_file
    "#{Rails.root}/log/application.log"      
  end 
  
  def custom_logger(path)
    @@custom_logger ||= CustomLogger.new(path)
  end

  def extract_status(payload)
    if payload[:status]
      payload[:status].to_i
    elsif payload[:exception]
      exception, message = error
      error_status_code(exception)
    else
      0
    end
  end

  def extract_error(payload)
    exception, message = payload[:exception]
    payload[:error] = "#{exception}:#{message.present? ? message.truncate(30).delete(" ").delete(",") : ''}"
  end

  def error_status_code(exception)
    # ActionDispatch::ExceptionWrapper.rescue_responses has a map as defined in :
    # https://github.com/rails/rails/blob/665ac7cff212d010a3573f85cea895666fbaad15/guides/source/configuring.md
    # Any exceptions that are not configured will be mapped to 500 Internal Server Error
    status = ActionDispatch::ExceptionWrapper.rescue_responses[exception]
    Rack::Utils.status_code(status)
  end

  def store_log_data(payload)
    CustomRequestStore.store[:controller_log_info] = payload
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
