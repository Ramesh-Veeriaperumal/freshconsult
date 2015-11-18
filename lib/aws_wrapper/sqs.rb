 $facebook_requeue_counter = 5
 $facebook_delay_seconds = 60
 class AwsWrapper::Sqs
  
  include Facebook::RedisMethods
   
  #Initialize with the sqs queue name
  def initialize(queue_name,options={})
    @aws_sqs = AWS::SQS.new.queues.named(queue_name,options)
  end

  #poll for the sqs queue
  def poll(clazz,method,opts={})
    @aws_sqs.poll(opts) do |msg|
      begin
        wait_on_poll if app_rate_limit_reached?
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


  def send_message(msg, options={})
    @aws_sqs.send_message(msg,options)
  end

  def requeue(msg, options={})
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
  
  private
  def wait_on_poll
    raise_sns_notification("APP RATE LIMIT - REACHED SKIPPING PROCESS")
    Rails.logger.error "Sleeping the process due to APP RATE LIMT"
    sleep(APP_RATE_LIMIT_EXPIRY)
  end
  
  def raise_sns_notification(subject)
    message = {:environment => Rails.env, :time_at => Time.now.utc, :sleep_for => APP_RATE_LIMIT_EXPIRY}
    topic = SNS["social_notification_topic"]
    DevNotification.publish(topic, subject, message.to_json)
  end
end
