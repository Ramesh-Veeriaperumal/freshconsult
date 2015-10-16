class RabbitmqWorker

  include Sidekiq::Worker
  include RabbitMq::Utils

  sidekiq_options :queue => 'rabbitmq_publish', :retry => 5, :dead => true, :failures => :exhausted

  def perform(exchange_key, message, rounting_key)
    # p "Exchange : #{exchange_key} || Key : #{rounting_key}"
    publish_message_to_xchg($rabbitmq_model_exchange[exchange_key], message, rounting_key)
    Rails.logger.info("Published RMQ message via Sidekiq")
    if reports_routing_key?(exchange_key, rounting_key)
      sqs_msg_obj = sqs_push(message)
      puts " SQS Message id - #{sqs_msg_obj.message_id} :: ROUTING KEY -- #{rounting_key} :: Exchange - #{exchange_key}"
    end
    # Handling only the network related failures
  rescue Bunny::ConnectionClosedError, Bunny::NetworkErrorWrapper, NoMethodError => e
    NewRelic::Agent.notice_error(e, {
                                   :custom_params => {
                                     :description => "RabbitMq Sidekiq Publish Error",
                                     :message     => message,
                                     :exchange    => exchange_key,
    }})
    # p "Inside Rescue! Requeueing!"
    Rails.logger.error("RabbitMq Sidekiq Publish Error: \n#{e.message}\n#{e.backtrace.join("\n")}")
    RabbitMq::Init.restart
    # Re-raising the error to have retry
    raise e
  end
  
  
  def sqs_push(message)
    $sqs_reports_etl.send_message(message)
  rescue => e
     sns_notification("Reports SQS push error", message)
     NewRelic::Agent.notice_error(e, {
                                   :custom_params => {
                                     :description => "Reports SQS push error",
                                     :message     => message
    }})
  end
  
  def reports_routing_key?(exchange, key)
    ((exchange.include?("tickets") || exchange.include?("notes")) && key[2] == "1") || 
      ((exchange.include?("archive_tickets") || exchange.include?("accounts")) && key[0] == "1")
  end

end
