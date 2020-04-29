class Billing::FreshcallerSubscriptionUpdate < BaseWorker
  include Sidekiq::Worker
  include Freshcaller::JwtAuthentication
  include Billing::OmniSubscriptionUpdateMethods

  sidekiq_options queue: :freshcaller_subscription_events_queue, retry: 5, failures: :exhausted

  def perform(params)
    freshcaller_request(construct_payload(params), FreshcallerSubscriptionConfig['subscription_host'], :post)
  rescue StandardError => e
    Rails.logger.error "Exception in updating freshcaller subscription. Account ID: #{Account.current.id}, Error message: #{e.message}"
    raise e
  end
end
