namespace :sqs do
  desc "Monitoring SQS"
  
  SQS_THRESHOLD = {
    :facebook_realtime_queue => 50
  }

  task :monitor => :environment do
    raise "Must provide QUEUE= " unless ENV['QUEUE'] # PRE-RAILS: Need to check this

    msgs_in_queue = AwsWrapper::SqsV2.get_queue_attributes(SQS[ENV['QUEUE'].to_sym], ['ApproximateNumberOfMessages']) || {}
    params = {
      queue_name: SQS[ENV['QUEUE'].to_sym],
      msgs_in_queue: msgs_in_queue['ApproximateNumberOfMessages'] 
    }
	 if msgs_in_queue > SQS_THRESHOLD[ENV["QUEUE"].to_sym]
      NewRelic::Agent.notice_error("SQS Threshold reached", :custom_params => params )
      SocialErrorsMailer.deliver_threshold_reached(params)
      puts "SQS threshold reached #{params.inspect}"
	 else
		  puts "SQS threshold have not reached #{params.inspect}"
	 end                                 
  end
  
end