# Send messages to the integrated channels like WhatsApp etc., via Freshchannel
class Channel::MessageWorker < BaseWorker
  include ChannelIntegrations::Multiplexer::MessageService

  sidekiq_options queue: :channel_reply_messages, retry: 5, backtrace: 10, failures: :exhausted
  
  def perform(args, msg_id = nil)
    args.symbolize_keys!
    post_message(Account.current, User.current, args)
  rescue => e
    Rails.logger.error "Exception in sending messages to Multiplexer \
      service: acc_id: #{Account.current.id}, user_id: #{User.current.id}, \
      Exception: #{e.message}, #{e.backtrace}"
    raise e
  end
end
