class Subscriptions::AddDeletedEvent < BaseWorker
  include Sidekiq::Worker
  include Subscription::Events::CalculateRevenue
  include Subscription::Events::Constants

  sidekiq_options :queue => :subscription_events_queue, :retry => 0, :failures => :exhausted

  def perform(args)
    account = Account.current
    subscription = account.subscription
    event_attributes = subscription_info(subscription).merge(deleted_event_info(subscription))
    SubscriptionEvent.create(event_attributes)
  rescue Exception => e
    puts e.inspect, args.inspect
    NewRelic::Agent.notice_error(e, {:args => args})
  end

  private
    def subscription_info(subscription)
      SUBCRIPTION_INFO.inject({}) { |h, (k, v)| h[k] = subscription[v]; h }
    end

    def deleted_event_info(subscription)
      {
        :account_id => subscription.account_id,
        :code => CODES[:deleted],
        :cmrr => subscription.cmrr
      }
    end
end