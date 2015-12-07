class DevNotificationWorker < BaseWorker
  
  sidekiq_options :queue => :dev_notification_worker, :retry => 0, :backtrace => true, :failures => :exhausted
    
  def perform args
    name    = args["name"]
    subject = args["subject"] ? args["subject"].gsub(/(\n|\t|\r|\\)/, "") : "Exception occured"
    message = args["message"]

    unless Rails.env.test?
      topic = $sns_client.create_topic({:name => name})
      $sns_client.publish(:topic_arn => topic[:topic_arn], :subject => subject, :message => message) 
    end
  end
  
end

