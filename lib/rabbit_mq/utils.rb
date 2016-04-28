require 'uuidtools'
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

  # Note: If message structure is changing here, make sure to check PostArchiveProcess file.
  def publish_to_rabbitmq(exchange, model, action)
    if RABBIT_MQ_ENABLED
      uuid    =  generate_uuid
      message = { 
        "object"                    =>  model,
        "action"                    =>  action,
        "action_epoch"              =>  Time.zone.now.to_f,
        "uuid"                      =>  uuid,
        "account_id"                =>  (model.eql?('account') ? self.id : self.account_id),
        "#{model}_properties"       =>  {}, 
        "subscriber_properties"     =>  {}
      }
      key = ""
      RabbitMq::Keys.const_get("#{exchange.upcase}_SUBSCRIBERS").each { |f|
        valid = construct_message_for_subscriber(f, message, model, action)
        key = generate_routing_key(key, valid)
      }
      send_message(uuid, exchange, message.to_json, key)
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
  def send_message(uuid, exchange, message, key)
    Rails.logger.debug "ROUTING KEY - #{key}"
    return unless key.include?("1")
    HelpkitFeedsLogger.log(Account.current.id, uuid, exchange, message, key)
    job_id = RabbitmqWorker.perform_async(Account.current.rabbit_mq_exchange_key(exchange), message, key)
    Rails.logger.debug "Sidekiq Job Id #{job_id} " 
  rescue => e
    NewRelic::Agent.notice_error(e,{:custom_params => {:description => "RabbitMq Publish Error",
                                                        :message => message.to_json }})
    handle_sidekiq_fail(uuid, exchange, message, key, e)
    Rails.logger.error("RabbitMq Publish Error: \n#{e.message}\n#{e.backtrace.join("\n")}")
    Rails.logger.error("RMQ Sidekiq push error: #{message}")
    sns_notification("RabbitMq Publish Error", message)
  end
  alias_method :manual_publish_to_xchg, :send_message

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
  
  def sns_notification(subj, message, topic = nil)
    notification_topic = topic || SNS["reports_notification_topic"]
    DevNotification.publish(notification_topic, subj, message.to_json)
  end

  def handle_sidekiq_fail(uuid, exchange, message, key, exception)
    FailedHelpkitFeed.create(
      account_id: Account.current.id,
      uuid: uuid,
      exchange: exchange,
      payload: message,
      routing_key: key,
      exception: exception
    )
  end

  def generate_uuid
    UUIDTools::UUID.timestamp_create.hexdigest
  end

  # Need this to invoke without AR objects
  module_function :generate_uuid, :manual_publish_to_xchg
end