class RabbitmqWorker

  include Sidekiq::Worker
  include RabbitMq::Utils

  sidekiq_options :queue => 'rabbitmq_publish', :retry => 5, :dead => true, :failures => :exhausted

  def perform(exchange_key, message, rounting_key)
    # p "Exchange : #{exchange_key} || Key : #{rounting_key}"
    publish_message_to_xchg($rabbitmq_model_exchange[exchange_key], message, rounting_key)
    Rails.logger.info("Published RMQ message via Sidekiq")
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

end
