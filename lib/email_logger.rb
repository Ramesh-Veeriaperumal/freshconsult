module EmailLogger
	    
	def logging_details
		begin
			logfile = File.open("#{Rails.root}/log/email.log", 'a')  # create log file		
			logfile.sync = true 
			application_logger = CustomLogger.new(logfile)	
			application_logger.info "from=#{request.parameters['from']}, to=#{request.parameters['to']}, headers=#{request.parameters['headers']}"
		rescue Exception => e
			NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Error occoured while capturing Application controller logs for splunk"}}) 
		end 		
	end
end
