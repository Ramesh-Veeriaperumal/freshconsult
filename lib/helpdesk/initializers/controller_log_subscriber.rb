class ControllerLogSubscriber <  ActiveSupport::LogSubscriber
  
  # http://www.paperplanes.de/2012/3/14/on-notifications-logsubscribers-and-bringing-sanity-to-rails-logging.html

  def process_action(event)
    log_details(event.payload)
  end

  def log_details(payload)
    begin
      path = log_file
      log_format = logging_format(payload)
      controller_logger = custom_logger(path)
      controller_logger.info "#{log_format}"
    rescue Exception => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Error occoured while capturing controller logs for #{path}"}})
    end
  end

  def logging_format(payload)
    @log_file_format = "ip=#{payload[:ip]}, account_id=#{payload[:account_id]}, domain=#{payload[:domain]}, url=#{payload[:url]}, path=#{payload[:path]}, controller=#{payload[:controller]}, action=#{payload[:action]}, server_ip=#{payload[:server_ip]}, status=#{payload[:status]}, format=#{payload[:format]}, db_runtime=#{payload[:db_runtime].round(2)}, view_time=#{payload[:view_runtime].round(2)}"
  end

  def log_file
    @log_file_path = "#{Rails.root}/log/application.log"      
  end 
  
  def custom_logger(path)
    @custom_logger||=CustomLogger.new(path)
  end

end

ControllerLogSubscriber.attach_to :action_controller
