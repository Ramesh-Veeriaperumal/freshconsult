module ChannelIntegrations::Utils
  module MessageParser
    include ChannelIntegrations::Constants

    def is_valid_request?(payload_type, payload)
      payload && is_valid_payload_type?(payload_type) && check_stack_info?(payload) && payload[:context] && payload[:command_name]
    end

    def check_stack_info?(payload)
      payload[:tenant] == ChannelFrameworkConfig['tenant']
    end

    # payload_types can be helpkit_command and channel_framework_reply.
    def is_valid_payload_type?(payload_type)
      payload_type && INCOMING_PAYLOAD_TYPES.include?(payload_type)
    end

    # Setting the msg_id in the redis to check for duplication.
    def perform_dedup_logic(args)
      return nil unless args[:msg_id]
      dedup_redis_key = DEDUP_REDIS_KEY % { msg_id: args[:msg_id] }
      dedup_interval = ChannelFrameworkConfig['dedup_interval'] ? ChannelFrameworkConfig['dedup_interval'].to_i.minutes : 1.hour
      $redis_integrations.perform_redis_op('setex', dedup_redis_key, dedup_interval, true)
    rescue => e
      Rails.logger.error "Unable to set the redis keys for dedup logic, msg_id: #{msg_id}"
    end
  end
end
