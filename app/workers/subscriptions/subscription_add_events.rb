class Subscriptions::SubscriptionAddEvents < BaseWorker

  include Sidekiq::Worker
  include Subscription::Events::Constants
  include Subscription::Events::AssignEventCode
  include Subscription::Events::CalculateRevenue

  sidekiq_options :queue => :subscription_events_queue, :retry => 0, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    subscription = Account.current.subscription
    old_subscription = args[:subscription_hash].symbolize_keys!
    old_subscription[:amount] = old_subscription[:amount].to_f if old_subscription
    event_attributes = assign_event_attributes(subscription, old_subscription)
    SubscriptionEvent.add_event(subscription.account, event_attributes) if event_attributes[:code]
  rescue Exception => e
    Rails.logger.debug "Exception while adding subscription event,\n#{e.message}\n#{e.backtrace.join("\n\t")}"
    NewRelic::Agent.notice_error(e, description: 'Exception while adding subscription event')
  end

  private

    def assign_event_attributes(subscription, old_subscription) 
      attributes = subscription_info(subscription)
      attributes[:code] = Subscriptions::SubscriptionAddEvents::assign_code(subscription, old_subscription)
      attributes[:code].blank? ? attributes :
            attributes.merge(revenue_info(subscription, old_subscription, attributes[:code]))
    end
    
    def subscription_info(subscription) 
      SUBCRIPTION_INFO.inject({}) { |h, (k, v)| h[k] = subscription[v]; h }
    end

    def revenue_info(subscription, old_subscription, code)
      {
        :revenue_type => Subscriptions::SubscriptionAddEvents::revenue_type(code),
        :cmrr => Subscriptions::SubscriptionAddEvents::calculate_cmrr(subscription, old_subscription, code)
      }
    end

end