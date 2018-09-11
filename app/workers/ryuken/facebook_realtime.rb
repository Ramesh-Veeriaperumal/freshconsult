class Ryuken::FacebookRealtime
  
  include Shoryuken::Worker  
  include Facebook::RedisMethods
  include Facebook::Exception::Notifier

  shoryuken_options queue: SQS[:facebook_realtime_queue], auto_delete: true, body_parser: :json,  batch: false

 
  def perform(sqs_msg)
    begin
      #Check for app rate limit before processing feeds
      wait_on_poll if app_rate_limit_reached?
      puts "FEED ===> #{sqs_msg.body}"
      Sqs::Message.new(sqs_msg.body).process
      
    rescue => e
      NewRelic::Agent.notice_error(e, {:description => "Error while processing sqs request"})
      raise e
    end
  end
end
