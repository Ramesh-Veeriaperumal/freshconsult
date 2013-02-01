class Subscription::Events::AddEvent
  
  include Subscription::Events::AssignEventCode
  include Subscription::Events::CalculateRevenue

  @queue = "events_queue"
  
  class << self

    def perform(subscription_id, cached_subscription_hash)
      subscription = Subscription.find(subscription_id)
      old_subscription = cached_subscription_hash.symbolize_keys!
      
      event_attributes = assign_event_attributes(subscription, old_subscription)
      SubscriptionEvent.add_event(subscription.account, event_attributes) if event_attributes[:code]
    end

    private

      def assign_event_attributes(subscription, old_subscription) 
        attributes = subscription_info(subscription)
        attributes[:code] = assign_code(subscription, old_subscription)
        attributes[:code].blank? ? attributes :
              attributes.merge(revenue_info(subscription, old_subscription, attributes[:code]))
      end
      
      def subscription_info(subscription) 
        SUBCRIPTION_INFO.inject({}) { |h, (k, v)| h[k] = subscription[v]; h }
      end

      def revenue_info(subscription, old_subscription, code)
        {
          :revenue_type => revenue_type(code),
          :cmrr => calculate_cmrr(subscription, old_subscription, code)
        }
      end
  end
end
