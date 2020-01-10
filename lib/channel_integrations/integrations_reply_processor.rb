module ChannelIntegrations
  class IntegrationsReplyProcessor
    include ChannelIntegrations::Utils::MessageParser

    def initialize
      @replies = Replies::Processor.new
    end

    def process(args)
      args.deep_symbolize_keys!
      payload_type = args[:payload_type]
      payload = args[:payload]

      return unless is_valid_request?(payload_type, payload) && args[:account_id]

      Sharding.select_shard_of(args[:account_id]) do
        Account.find(args[:account_id]).make_current
        log_params(payload)
        @replies.process(payload)
        perform_dedup_logic(args)
      end
    rescue ActiveRecord::RecordNotFound, ActiveRecord::AdapterNotSpecified, ShardNotFound => e
      Rails.logger.debug "#{e.inspect} -- #{args[:account_id]}"
    ensure
      Account.reset_current_account
    end

    private

      def log_params(payload)
        Rails.logger.debug "channel framework reply, owner: #{payload[:owner]}, command: #{payload[:command_name]}, command_id: #{payload[:command_id]}, meta: #{payload[:meta].inspect}"
      end
  end
end
