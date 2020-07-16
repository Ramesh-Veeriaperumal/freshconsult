# A singleton class to store the AWS SQS queue. The queue is only loaded once on an on-demand basis.
class AwsWrapper::SqsQueue
  
  include Singleton

  def initialize
    @queues = {} # a hash storing all the queues
  end

  def send_message(queue, message, options={})
    queue = named(queue)

    Rails.logger.info "Queue found: #{queue}"
    queue.send_message(message, options) if queue
  end

  private
    def named(queue_name)
      queue = @queues[queue_name]
      if queue.blank?
        queue = @queues[queue_name] = AWS::SQS.new.queues.named(queue_name)
      end
      queue
    end
end