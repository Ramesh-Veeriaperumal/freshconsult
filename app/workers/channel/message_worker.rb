# frozen_string_literal: true

# Send messages to the integrated channels like WhatsApp etc., via Freshchannel
# ------------------------------------------------------------------------------
# Worker is primarily written to handle the latency of ticket replies which got
# created via Smooch(WhatsApp) integration. Once we migrate all 100 accounts from
# Smooch integration to native WhatsApp channel, we can remove this worker and
# post message to Multiplexer service synchronously during the ticket reply request.
class Channel::MessageWorker < BaseWorker
  include ChannelIntegrations::Multiplexer::MessageService

  sidekiq_options queue: :channel_reply_messages, retry: 5, backtrace: 10, failures: :exhausted

  def perform(args, _msg_id = nil)
    args.symbolize_keys!
    post_message(User.current, args)
  rescue => e
    Rails.logger.error "Exception in sending messages to Multiplexer \
      service: acc_id: #{Account.current.id}, user_id: #{User.current.id}, \
      Exception: #{e.message}, #{e.backtrace}"
    raise e
  end
end
