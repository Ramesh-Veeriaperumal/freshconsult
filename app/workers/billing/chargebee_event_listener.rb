class Billing::ChargebeeEventListener < BaseWorker
  include Sidekiq::Worker
  include Billing::ChargebeeEventListenerMethods

  sidekiq_options queue: :subscription_events_queue, retry: 5, failures: :exhausted

  def perform(args)
    event_data = JSON.parse(args.to_json, object_class: OpenStruct)
    safe_send(event_data.event_type, event_data, Account.current)
    Rails.logger.info "#{event_data.event_type} Chargebee event got executed for account: #{Account.current.id}"
  rescue StandardError => e
    Rails.logger.error "Exception while processing Chargebee subscription event \
      acc_id: #{Account.current.try(:id)}, args: #{args.inspect}, error message: \
      #{e.message}, error: #{e.backtrace.join('\n')}"
    raise e
  end
end
