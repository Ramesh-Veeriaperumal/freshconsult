module RabbitMq::Utils

  include RabbitMq::Constants

=begin
  {
    "object" => "ticket/note",
    "verb" => "new/update",
    "properties" => {
      All the req ticket properties
    },
    "subscriber_properties" => {
      "auto_refresh" => {
        "fayeChannel" => .. #all other custom properties which each subscriber needs
      },
      "mobile_app" => {
         #custom data needed by mobile_app
      }
    }
  }
=end

  private

  def publish_to_rabbitmq(exchange, model, action)
    if RABBIT_MQ_ENABLED
      message = { 
        "object"                =>  model,
        "action"                =>  action,
        "action_epoch"          =>  Time.zone.now.to_i,
        "#{model}_properties"   =>  {}, 
        "subscriber_properties" =>  {}        
      }
      key = ""
      RabbitMq::Keys.const_get("#{model.upcase}_SUBSCRIBERS").each { |f|
        valid = construct_message_for_subscriber(f, message, model, action)
        key = generate_routing_key(key, valid)
      }
      send_message(exchange, message.to_json, key)
    end
  end

  def generate_routing_key(old_key, val)
    key = val ? "1" : "0"
    old_key.present? ? "#{old_key}.#{key}" : key
  end

  def construct_message_for_subscriber(s, message, model, action)
    valid = send("mq_#{s}_valid", action)
    if valid  
      message["#{model}_properties"].deep_merge!(send("mq_#{s}_#{model}_properties", action))
      message["subscriber_properties"].merge!({ s => send("mq_#{s}_subscriber_properties", action) })
    end
    valid
  end

  #made this as a function, incase later we want to compress the data before sending
  def send_message(exchange, message, key)
    return unless key.include?("1")
    self.class.trace_execution_scoped(['Custom/RabbitMQ/Send']) do
      Timeout::timeout(CONNECTION_TIMEOUT) {
        publish_message_to_xchg(Account.current.rabbit_mq_exchange(exchange), message, key)
      }
    end
  rescue Timeout::Error => e 
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "RabbitMq Timeout Error"}})
    Rails.logger.error("RabbitMq Timeout Error: \n#{e.message}\n#{e.backtrace.join("\n")}")
    RabbitmqWorker.perform_async(Account.current.rabbit_mq_exchange_key(exchange), message, key)
    RabbitMq::Init.restart
  rescue => e
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "RabbitMq Publish Error - Auto-refresh"}})
    Rails.logger.error("RabbitMq Publish Error: \n#{e.message}\n#{e.backtrace.join("\n")}")
    RabbitmqWorker.perform_async(Account.current.rabbit_mq_exchange_key(exchange), message, key)
    RabbitMq::Init.restart
  end

  def publish_message_to_xchg(exchange, message, key)
    # Having all the messages as persistant is an overkill. Need to refactor
    # so that the options for publish can be passed as a parameter. Messages
    # should also have message_id for unique identification
    exchange.publish(
      message, 
      :routing_key => key,
      :persistant => true
    )
  end

end