class ControllerLogSubscriber <  ActiveSupport::LogSubscriber
  
  # http://www.paperplanes.de/2012/3/14/on-notifications-logsubscribers-and-bringing-sanity-to-rails-logging.html

  def process_action(event)
    log_details(event.payload)
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
    log_file_format = "ip=#{payload[:ip]}, account_id=#{payload[:account_id]}, domain=#{payload[:domain]}, url=#{payload[:url]}, path=#{payload[:path]}, controller=#{payload[:controller]}, action=#{payload[:action]}, server_ip=#{payload[:server_ip]}, status=#{payload[:status]}, format=#{payload[:format]}, db_runtime=#{payload[:db_runtime]}, view_time=#{payload[:view_runtime]}, shard_name=#{payload[:shard_name]}"
  end

  def log_file
    "#{Rails.root}/log/application.log"      
  end 
  
  def custom_logger(path)
    @@custom_logger ||= CustomLogger.new(path)
  end

end

ControllerLogSubscriber.attach_to :action_controller
