class Billing::UpdateAccountDomain < BaseWorker
  include Sidekiq::Worker

  sidekiq_options queue: :subscription_events_queue, retry: 5, failures: :exhausted

  def perform
    account = Account.current
    subscription = account.subscription
    subscription.billing.update_customer(account.id, {})
    Rails.logger.info "Updated account domain in chargebee for account: #{account.id}"
  rescue StandardError => e
    Rails.logger.error "Exception in updating account domain. Account ID: #{account.id}, Error message: #{e.message}"
    raise e
  end
end
