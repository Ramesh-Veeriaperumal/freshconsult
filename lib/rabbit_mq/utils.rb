module RabbitMq::Utils
  include RabbitMq::Keys

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

  def publish_to_rabbitmq(model, action)
    if RABBIT_MQ_ENABLED
      message = { "object" => model,
                  "action" => action,
                  "#{model}_properties" => {}, 
                  "subscriber_properties" => {} 
                }
      key = ""
      RabbitMq::Keys.const_get("#{model.upcase}_SUBSCRIBERS").each { |f|
        valid = construct_message_for_subscriber(f, message, model, action)
        key = generate_routing_key(key, valid)
      }
      send_message(message, key)
    end
  end

  def generate_routing_key(old_key, val)
    key = val ? "1" : "0"
    old_key.present? ? "#{old_key}.#{key}" : key
  end

  def construct_message_for_subscriber(s, message, model, action)
    valid = send("mq_#{s}_valid")
    if valid
      message["#{model}_properties"].merge!(send("mq_#{s}_#{model}_properties"))
      message["subscriber_properties"].merge!({ s => send("mq_#{s}_subscriber_properties") })
    end
    valid
  end

  #made this as a function, incase later we want to compress the data before sending
  def send_message(message, key)
    self.class.trace_execution_scoped(['Custom/RabbitMQ/Send']) do
      account.rabbit_mq_exchange.publish(message.to_json, :routing_key => key, :persistant => true) if key.include?("1")  
    end    
  rescue => e
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "RabbitMq Publish Error - Auto-refresh"}})
    Rails.logger.error("RabbitMq Publish Error: \n#{e.message}\n#{e.backtrace.join("\n")}")
    RabbitMq::Init.start
  end
end