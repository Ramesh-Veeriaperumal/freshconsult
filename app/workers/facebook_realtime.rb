class FacebookRealtime
  
  include Shoryuken::Worker  
  include Facebook::RedisMethods
  include Facebook::Exception::Notifier

  shoryuken_options queue: SQS[:facebook_realtime_queue], auto_delete: true, body_parser: :json,  batch: true

 
  def perform(sqs_msgs, args)
    begin
      #Check for app rate limit before processing feeds
      wait_on_poll if app_rate_limit_reached?
      
      sqs_msg.each do |sqs_msg|
        puts "FEED ===> #{sqs_msg.body}"
        Sqs::Message.new(sqs_msg.body).process
      end
      
    rescue => e
      NewRelic::Agent.notice_error(e, {:description => "Error while processing sqs request"})
    end
  end
end
