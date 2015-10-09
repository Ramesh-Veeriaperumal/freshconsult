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
      RabbitMq::Keys.const_get("#{exchange.upcase}_SUBSCRIBERS").each { |f|
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
    valid = send("mq_#{s}_valid", action, model)
    if valid  
      message["#{model}_properties"].deep_merge!(send("mq_#{s}_#{model}_properties", action))
      message["subscriber_properties"].merge!({ s => send("mq_#{s}_subscriber_properties", action) })
    end
    valid
  end

  #made this as a function, incase later we want to compress the data before sending
  def send_message(exchange, message, key)
    Rails.logger.debug "ROUTING KEY - #{key}"
    return unless key.include?("1")
    self.class.trace_execution_scoped(['Custom/RabbitMQ/Send']) do
      Timeout::timeout(CONNECTION_TIMEOUT) {
        Rails.logger.debug " Inside send message to RMQ - #{Account.current.id} -- #{exchange}"
        publish_message_to_xchg(Account.current.rabbit_mq_exchange(exchange), message, key)
      }
    end
  rescue Timeout::Error => e 
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "RabbitMq Timeout Error"}})
    Rails.logger.error("RabbitMq Timeout Error: \n#{e.message}\n#{e.backtrace.join("\n")}")
    job_id = RabbitmqWorker.perform_async(Account.current.rabbit_mq_exchange_key(exchange), message, key)
    Rails.logger.debug "Sidekiq Job Id #{job_id} ---- #{Account.current.id} -- #{exchange}"
    RabbitMq::Init.restart
  rescue => e
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "RabbitMq Publish Error - Auto-refresh"}})
    Rails.logger.error("RabbitMq Publish Error: \n#{e.message}\n#{e.backtrace.join("\n")}")
    job_id = RabbitmqWorker.perform_async(Account.current.rabbit_mq_exchange_key(exchange), message, key)
    Rails.logger.debug "Sidekiq Job Id #{job_id} ----- #{Account.current.id} -- #{exchange}"
    RabbitMq::Init.restart
  end

  def publish_message_to_xchg(exchange, message, key)
    # Having all the messages as persistant is an overkill. Need to refactor
    # so that the options for publish can be passed as a parameter. Messages
    # should also have message_id for unique identification
    Rails.logger.debug "Gonna publish to RMQ for #{Account.current.id}"
    exchange.publish(
      message, 
      :routing_key => key,
      :persistant => true
    )
    Rails.logger.debug "Finished publish to RMQ for #{Account.current.id}"
  end
  
  
  def manual_publish_to_xchg(exchange, message, key, sidekiq = false)
    # Decide we gonna publish message to exchange via sidekiq or diretly
    # Currently we directly push to exchange
    # If there is any performance, then we can push via sidekiq
    return unless Account.current.reports_enabled?
    if sidekiq
      RabbitmqWorker.perform_async(Account.current.rabbit_mq_exchange_key(exchange), message, key)
    else
      send_message(exchange, message, key)
    end
  end

end