# This uses aws sdk version 2
module AwsWrapper
  class SqsV2

    # _Note_: Acceptable params for QueuePoller are:
    # client                  => Need to pass
    # max_number_of_messages  => Need to pass
    # wait_time_seconds       => Can get from Queue by default
    # visibility_timeout      => Can get from Queue by default
    
    def self.send_message(queue_name, message_body, delay_seconds = 0, options = {})
      $sqs_v2_client.send_message(
        queue_url: SQS_V2_QUEUE_URLS[queue_name],
        message_body: message_body,
        delay_seconds: delay_seconds
      )
    end

    # Polls in intervals of time
    #
    def self.long_poll(queue_name, options = {}, &block)
      poller = Aws::SQS::QueuePoller.new(SQS_V2_QUEUE_URLS[queue_name], client: $sqs_v2_client)
      poll_options = queue_attributes(queue_name).merge(options).merge(max_number_of_messages: 10)
      poller.poll(poll_options) do |messages|
        messages.each do |msg| 
          yield(msg) if block_given?
        end
      end
    end

    # Polls incessantly
    #
    def self.poll(queue_name, options={}, &block)
      poller = Aws::SQS::QueuePoller.new(SQS_V2_QUEUE_URLS[queue_name], client: $sqs_v2_client)
      poll_options = queue_attributes(queue_name).merge(options).merge(wait_time_seconds: nil, max_number_of_messages: 10)
      poller.poll(poll_options) do |messages|
        messages.each do |msg| 
          yield(msg) if block_given?
        end
      end
    end
      
    private
      
      def self.queue_url(queue_name)
        $sqs_v2_client.get_queue_url(queue_name: queue_name).queue_url
      end

      def self.queue_attributes(queue_name)
        attributes = $sqs_v2_client.get_queue_attributes(
          queue_url: SQS_V2_QUEUE_URLS[queue_name], 
          attribute_names: ['VisibilityTimeout','ReceiveMessageWaitTimeSeconds']
        ).attributes

        {
          visibility_timeout: attributes['VisibilityTimeout'],
          wait_time_seconds: attributes['ReceiveMessageWaitTimeSeconds']
        }
      end
  end
end