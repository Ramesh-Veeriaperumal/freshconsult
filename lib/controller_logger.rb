module ControllerLogger

  CONTROLLER_LOGGER = CustomLogger.new("#{Rails.root}/log/application.log")

  def logging_details
    begin
      log_format = logging_format
      controller_logger = custom_logger
      controller_logger.info "#{log_format}"
    rescue Exception => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Error occoured while capturing controller logs for #{path}"}}) 
      FreshdeskErrorsMailer.error_email(nil,nil,e,{:subject => "Splunk logging Error at ControllerLogger",:recipients => "pradeep.t@freshdesk.com"})  
    end
  end
  
  def logging_format
    @log_file_format = "ip=#{request.env['CLIENT_IP']}, domain=#{request.env['HTTP_HOST']}, controller=#{request.parameters[:controller]}, action=#{request.parameters[:action]}, url=#{request.url}, server_ip=#{request.env['SERVER_ADDR']}"     
  end 

  def custom_logger
    CONTROLLER_LOGGER
  end
    
end