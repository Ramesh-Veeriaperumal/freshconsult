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

  def subscriber_basic_message(model, action, uuid)
    { 
      "object"                =>  model,
      "action"                =>  action,
      "action_epoch"          =>  fetch_action_epoch,
      "uuid"                  =>  uuid,
      "actor"                 =>  User.current.try(:id).to_i,
      "account_id"            =>  Account.current.id,
      "shard"                 =>  shard_info,
      "#{model}_properties"   =>  {},
      "subscriber_properties" =>  {},
      "bulk_publish"          =>  false
    }
  end

  #to avoid race condition in epoch time.
  def fetch_action_epoch
    time_arr = [Time.zone.now.to_f]
    time_arr.push(self.updated_at.to_f) if respond_to?(:updated_at)
    time_arr.push((created_at.to_f + 0.001)) if respond_to?(:created_at)
    time_arr.max
  end

  def publish_to_rabbitmq(exchange, model, action)
    if RABBIT_MQ_ENABLED
      uuid    = self.event_uuid || generate_uuid
      message = subscriber_basic_message(model, action, uuid)
      key = ""
      RabbitMq::Keys.const_get("#{exchange.upcase}_SUBSCRIBERS").each { |f|
        begin
          valid = construct_message_for_subscriber(f, message, model, action)
        rescue => e
          valid = false
          Rails.logger.error e.backtrace.join("\n")
          Rails.logger.info "Publisher payload construct Error.. #{e.message}, #{message.to_json}"
        ensure
          key = generate_routing_key(key, valid)
        end
      }
      message["routing_key"] = key
      message["pod"] = ChannelFrameworkConfig['pod']
      send_message(uuid, exchange, message.to_json, key)
    end
  end

  def generate_routing_key(old_key, val)
    key = val ? "1" : "0"
    old_key.present? ? "#{old_key}.#{key}" : key
  end

  def construct_message_for_subscriber(s, message, model, action)
    valid = safe_send("mq_#{s}_valid", action, model)
    if valid
      message["#{model}_properties"].deep_merge!(safe_send("mq_#{s}_#{model}_properties", action))
      message["subscriber_properties"].merge!({ s => safe_send("mq_#{s}_subscriber_properties", action) })
      safe_send("mq_custom_#{s}_#{model}_method", message) if CUSTOM_METHODS[model] && CUSTOM_METHODS[model].include?(s)
    end
    valid
  end

  def subscriber_manual_publish(model, action, options, uuid)
    message = subscriber_basic_message(model, action, uuid)
    MANUAL_PUBLISH_SUBCRIBERS.each { |f|
      begin
        next if f == "activities" && model == "archive_ticket"
        next if f == 'count' && model != 'ticket'

        message["#{model}_properties"].deep_merge!(safe_send("mq_#{f}_#{model}_properties", action))
        message["subscriber_properties"].merge!({ f => safe_send("mq_#{f}_subscriber_properties", action)})
      rescue => e
        Rails.logger.info "Manual Publisher payload construct Error.. #{e.message}, #{message.to_json}"
      end
    }
    # Currently need options only for reports, so adding all options directly to reports
    # TODO Need to change options as hash with subscriber name as key and modify the code as generic
    message["subscriber_properties"]["reports"].merge!(options) if message["subscriber_properties"]["reports"].present?
    message["bulk_publish"] = true
    message.to_json
  end

  #made this as a function, incase later we want to compress the data before sending
  def send_message(uuid, exchange, message, key, manual_publish = false)
    Rails.logger.debug "ROUTING KEY - #{key}"
    return unless key.include?("1")
    HelpkitFeedsLogger.log(Account.current.id, uuid, exchange, message, key)
    job_id = if manual_publish
      ManualPublishWorker.perform_async( exchange.pluralize, #remove pluralize after taking all to lambda
                                           message, 
                                           key, 
                                           Account.current.launched?(:lambda_exchange))
    else
      RabbitmqWorker.perform_async( exchange.pluralize, #remove pluralize after taking all to lambda
                                           message, 
                                           key, 
                                           Account.current.launched?(:lambda_exchange))
    end
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
    notification_topic = topic || SNS["dev_ops_notification_topic"]
    DevNotification.publish(notification_topic, subj, message.to_json)
  end

  def shard_info
    ActiveRecord::Base.current_shard_selection.shard
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
  module_function :generate_uuid, :manual_publish_to_xchg, :handle_sidekiq_fail, :subscriber_basic_message, :sns_notification
end
