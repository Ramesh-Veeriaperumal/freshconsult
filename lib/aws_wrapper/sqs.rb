 $facebook_requeue_counter = 5
 $facebook_delay_seconds = 60
 class AwsWrapper::Sqs
  #Initialize with the sqs queue name
  def initialize(queue_name,options={})
    @aws_sqs = AWS::SQS.new.queues.named(queue_name,options)
  end

  #poll for the sqs queue
  def poll(clazz,method,opts={})
    @aws_sqs.poll(opts) do |msg|
      begin
        puts "#{msg}"
        Rails.logger.error "#{msg}"
        clazz.constantize.new(msg.body).send(method)
      rescue Exception => e
        Rails.logger.error "Error while processing =============> #{e.inspect}"
        NewRelic::Agent.notice_error(e,{:description => "Error while processing sqs request"})
        #render :text => "Request cannot be processed"
      end
    end
  end


  def send_message(msg,options={})
    @aws_sqs.send_message(msg,options)
  end

  def requeue(msg,options={})
    if msg["counter"]
      msg["counter"] = msg["counter"].to_i + 1
      return false if msg["counter"] > $facebook_requeue_counter #removing from the queue after 15 mins
    else
      msg["counter"] = 1
    end
    options[:delay_seconds] = msg["counter"]*$facebook_delay_seconds
    msg = msg.to_json
    send_message(msg,options)
    return true
  end
end
