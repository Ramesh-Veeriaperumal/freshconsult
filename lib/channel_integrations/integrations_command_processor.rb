module ChannelIntegrations
  class IntegrationsCommandProcessor
    include ChannelIntegrations::Utils::MessageParser
    include ChannelIntegrations::Utils::Schema
    include KafkaCollector::CollectorRestClient

    def initialize
      @cmds = Commands::Processor.new
    end

    def process(args)
      args.deep_symbolize_keys!
      payload_type = args[:payload_type]
      payload = args[:payload]

      return unless is_valid_request?(payload_type, payload) && args[:account_id]
      Sharding.select_shard_of(args[:account_id]) do
        Account.find(args[:account_id]).make_current
        return unless valid_twitter_update?(payload)
        log_params(payload)
        reply_payload = @cmds.process(payload)
        send_integrations_reply(reply_payload, args) unless reply_payload.blank?
        perform_dedup_logic(args)
      end
    rescue ActiveRecord::RecordNotFound, ActiveRecord::AdapterNotSpecified, ShardNotFound => e
      Rails.logger.debug "#{e.inspect} -- #{args[:account_id]}"
    ensure
      Account.reset_current_account
    end

    private

      def send_integrations_reply(reply_payload, args)
        post_to_collector(build_reply_payload(reply_payload, args))
      end

      def build_reply_payload(payload, args) # payload contains data, status_code and reply_status.
        owner = args[:payload][:owner]
        command = args[:payload][:command_name]
        reply_schema = default_reply_schema(owner, command, args[:payload])

        reply_json = {
          payload_type: ChannelIntegrations::Constants::PAYLOAD_TYPES[:reply_from_helpkit],
          account_id: args[:account_id],
          payload: payload.merge!(reply_schema)
        }.to_json

        reply_json
      end

      def log_params(payload)
        Rails.logger.debug "channel framework command, owner: #{payload[:owner]}, command: #{payload[:command_name]}, command_id: #{payload[:command_id]}, meta: #{payload[:meta].inspect}"
      end
  end
end
