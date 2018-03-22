class Bot::FeedbackPoller
  include Shoryuken::Worker
  
  shoryuken_options queue: SQS[:bot_feedback_queue], auto_delete: true, body_parser: :json, batch: true

  def perform(sqs_msgs, args)
    sqs_msgs.each do |sqs_msg|
      begin
        args = JSON.parse(sqs_msg.body)['data']
        bot_feedback = Bot::FeedbackProcessor.new(args.deep_symbolize_keys)
        bot_feedback.process if bot_feedback.valid?
      rescue => e
        NewRelic::Agent.notice_error(e, description: 'Error while processing Bot FeedbackPoller message #{e}')
      end
    end
  end

end