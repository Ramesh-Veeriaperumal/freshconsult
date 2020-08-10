class Ryuken::FacebookRealtime
  
  include Shoryuken::Worker  
  include Facebook::RedisMethods
  include Facebook::Exception::Notifier
  include Facebook::CentralMessageUtil

  shoryuken_options queue: SQS[:facebook_realtime_queue], auto_delete: true, body_parser: :json,  batch: false

  def perform(sqs_msg, args)
    begin
      #Check for app rate limit before processing feeds
      wait_on_poll if app_rate_limit_reached?

      type = CENTRAL_PAYLOAD_TYPES[:feeds]
      body = get_message(sqs_msg.body, type)

      if body.present?
        Sqs::Message.new(body).process
      else
        Rails.logger.debug "Message intented for another pod"
      end
    rescue => e
      NewRelic::Agent.notice_error(e, {:description => "Error while processing sqs request"})
      Rails.logger.error "Error while processing sqs request, error: #{e.message}"
      raise e
    end
  end
end
