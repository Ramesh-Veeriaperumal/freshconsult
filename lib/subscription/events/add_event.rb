class Subscription::Events::AddEvent
  extend Resque::AroundPerform

  include Subscription::Events::AssignEventCode
  include Subscription::Events::CalculateRevenue

  @queue = "events_queue"
  
  class << self

    def on_failure_query_with_args(exception,*args)
      puts "Came to event specific exception"
      case exception
        when NoMethodError
          if args[0] and !args[0].is_a?(Hash)
            subscription = Subscription.find(args[0])
            account_id = subscription.account_id 
            Resque.enqueue(self.name.constantize, {:account_id => account_id,
                                                   :subscription_id => args[0],
                                                   :subscription_hash => args[1]})
          end
        else
        puts "Do nothing"
      end
    end

    def perform(args)
      args.symbolize_keys!
      subscription = Subscription.find(args[:subscription_id])
      old_subscription = args[:subscription_hash].symbolize_keys!
      
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
