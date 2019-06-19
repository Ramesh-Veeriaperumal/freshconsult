module SqsHelperMethods
  REQUEUE_LIMIT = 5
  REQUEUE_DELAY = 60 # Seconds

  # A backoff requeue for SQS queues
  # For this approach a message counter value is used. This counter is stored in the sqs message
  # maximum delay seconds is 900 seconds (15 mins)
  def requeue(queue_name, message, options = {})
    if options[:delay_seconds].nil?
      message['counter'] = message['counter'].to_i + 1
      return false if message['counter'] > (options[:requeue_limit] || REQUEUE_LIMIT)

      options[:delay_seconds] = message['counter'] * (options[:requeue_delay] || REQUEUE_DELAY)
    end
    AwsWrapper::SqsV2.send_message(queue_name, message.to_json, options[:delay_seconds] > 900 ? 900 : options[:delay_seconds])
  end
end
