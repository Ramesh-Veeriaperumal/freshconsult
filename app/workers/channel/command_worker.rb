# Worker to post to the commands to the Central's Collector.
class Channel::CommandWorker < BaseWorker
  include KafkaCollector::CollectorRestClient

  sidekiq_options queue: :channel_framework_command,
                  retry: 0,
                  failures: :exhausted

  def perform(args, msg_id = nil)
    args.symbolize_keys!
    post_to_collector(get_payload(args), msg_id)
  end

  private

    def get_payload(args)
      args[:payload_type] = args.delete(:override_payload_type) ||
                            ChannelIntegrations::Constants::PAYLOAD_TYPES[:command_to_channel]
      args[:account_id] = Account.current.id.to_s
      args.to_json
    end
end
