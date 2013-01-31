class Subscription::Events::AddDeletedEvent

	include Subscription::Events::CalculateRevenue

	@queue = "events_queue"

	class << self

		def perform(deleted_subscription_hash)
			subscription = deleted_subscription_hash.symbolize_keys!

			event_attributes = subscription_info(subscription).merge(deleted_event_info(subscription))
			SubscriptionEvent.create(event_attributes)
		end

	private

		def subscription_info(subscription) 
			SUBCRIPTION_INFO.inject({}) { |h, (k, v)| h[k] = subscription[v]; h }
		end

		def deleted_event_info(subscription)
			{
				:account_id => subscription[:account_id],
				:code => CODES[:deleted],
				:cmrr => (subscription[:amount]/subscription[:renewal_period])
			}
		end

	end
end