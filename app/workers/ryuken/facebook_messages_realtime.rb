class Ryuken::FacebookMessagesRealtime

  include Shoryuken::Worker  
  include Facebook::RedisMethods
  include Facebook::Exception::Notifier

  shoryuken_options queue: SQS[:fb_message_realtime_queue], auto_delete: true, body_parser: :json,  batch: true

  
  def perform(sqs_msgs, args)
    begin
      #Check for app rate limit before processing feeds
      wait_on_poll if app_rate_limit_reached?
      sqs_msgs.each do |sqs_msg|
        puts "Facebook RT Message ===> #{sqs_msg.body}"
        facebook_message = Sqs::FacebookMessage.new(sqs_msg.body)
        facebook_message.process
      end
      
    rescue => e
      NewRelic::Agent.notice_error(e, {:description => "Error while processing sqs request"})
    end
  end
end
