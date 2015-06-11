module ResqueLogger
  def logging_details(queue,account_id)
    begin
      path = log_file
      log_format = logging_format(queue,account_id)
      controller_logger = custom_logger(path)
      controller_logger.info "#{log_format}"
    rescue Exception => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Error occoured while capturing controller logs for #{path}"}}) 
      FreshdeskErrorsMailer.error_email(nil,nil,e,{:subject => "ResqueLogger logging Error",:recipients => "pradeep.t@freshdesk.com"})  
    end
  end

  def log_file
    @log_file_path = "#{Rails.root}/log/big_brother_resque.log"
  end
  
  def logging_format(queue,account_id)
    @log_file_format = "resque.#{queue}.#{account_id}"
  end

  def custom_logger(path)
    @custom_logger||=CustomLogger.new(path)
  end
    
end