class Billing::FreshchatSubscriptionUpdate < BaseWorker
  include Sidekiq::Worker
  include Freshchat::Util
  include Billing::OmniSubscriptionUpdateMethods

  sidekiq_options queue: :freshchat_subscription_events_queue, retry: 5, failures: :exhausted

  def perform(params)
    params.deep_symbolize_keys!
    freshchat_subscription_request(construct_payload(params)) if params[:content][:subscription].present?
  rescue StandardError => e
    Rails.logger.error "Exception in updating freshchat subscription. Account ID: #{Account.current.id}, Error message: #{e.message}"
    raise e
  end
end
