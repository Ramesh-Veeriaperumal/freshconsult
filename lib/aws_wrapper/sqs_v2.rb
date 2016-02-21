# This uses aws sdk version 2
module AwsWrapper
  class SqsV2
    
    def self.send_message(queue_name, message_body, delay_seconds = 0, options = {})
      $sqs_v2_client.send_message(
        queue_url: queue_url(queue_name),
        message_body: message_body.to_json,
        delay_seconds: delay_seconds
      )
    end

    # Polls in intervals of time
    #
    def self.long_poll(queue_name, options = {}, &block)
      poller = Aws::SQS::QueuePoller.new(queue_url(queue_name), client: $sqs_v2_client)
      poll_options = options.merge(max_number_of_messages: 10,
                                   visibility_timeout: 600)
      poller.poll(poll_options) do |messages|
        messages.each do |msg| 
          yield(msg) if block_given?
        end
      end
    end

    # Polls incessantly
    #
    def self.poll(queue_name, options={}, &block)
      poller = Aws::SQS::QueuePoller.new(queue_url(queue_name), client: $sqs_v2_client)
      poll_options = options.merge(
                                    wait_time_seconds: nil,
                                    max_number_of_messages: 10,
                                    visibility_timeout: 600
                                  )
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
  end
end