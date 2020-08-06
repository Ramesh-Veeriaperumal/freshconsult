class Ryuken::ChannelMessagePoller
  include Shoryuken::Worker
  shoryuken_options queue: SQS[:channel_framework_services], auto_delete: true, body_parser: :json

  def perform(sqs_msg, args)
    args = JSON.parse(sqs_msg.body)['data']
    payload_type = args['payload_type']
    worker_obj = create_worker_object(payload_type)
    worker_obj.process(args) if worker_obj && !duplicate_message?(args)
  rescue StandardError => e
    NewRelic::Agent.notice_error(e, description: 'Error while processing sqs request')
    raise e
  end

  private

    # Checking for duplicate messages before processing.
    def duplicate_message?(args)
      payload = args.symbolize_keys
      return true unless payload[:msg_id]
      redis_key = ChannelIntegrations::Constants::DEDUP_REDIS_KEY % { msg_id: payload[:msg_id] }
      if $redis_integrations.perform_redis_op('get', redis_key)
        Rails.logger.error "Received a duplicate message #{payload[:msg_id]}"
        true
      else
        false
      end
    end

    def create_worker_object(payload_type)
      return nil unless payload_type
      payload_types = ChannelIntegrations::Constants::PAYLOAD_TYPES

      if payload_type == payload_types[:command_to_helpkit]
        ChannelIntegrations::IntegrationsCommandProcessor.new
      elsif payload_type == payload_types[:reply_from_channel]
        ChannelIntegrations::IntegrationsReplyProcessor.new
      end
    end
end
