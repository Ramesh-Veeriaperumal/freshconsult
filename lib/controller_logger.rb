module ControllerLogger
  def logging_details
    begin
      path = log_file
      log_format = logging_format
      controller_logger = custom_logger(path)
      controller_logger.info "#{log_format}"
    rescue Exception => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Error occoured while capturing controller logs for #{path}"}}) 
      FreshdeskErrorsMailer.error_email(nil,nil,e,{:subject => "Splunk logging Error at ControllerLogger",:recipients => "pradeep.t@freshdesk.com"})  
    end
  end

  def log_file
    @log_file_path = "#{Rails.root}/log/application.log"      
  end 
  
  def logging_format
    @log_file_format = "ip=#{request.env['CLIENT_IP']}, domain=#{request.env['HTTP_HOST']}, controller=#{request.parameters[:controller]}, action=#{request.parameters[:action]}, url=#{request.url}, server_ip=#{request.env['SERVER_ADDR']}"     
  end 

  def custom_logger(path)
    @custom_logger||=CustomLogger.new(path)
  end
    
end