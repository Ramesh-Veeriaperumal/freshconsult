class Subscription < ActiveRecord::Base
  include SubscriptionHelper
  after_update :create_omni_plan_ticket, if: :ticket_create_condition

  private

    def create_omni_plan_ticket
      ProductFeedbackWorker.perform_async(omni_channel_ticket_params(Account.current,
                                                                     @old_subscription, User.current))
    end

    def ticket_create_condition
      new_subscription = Account.current.subscription
      plan_changed? && omni_plan_change?(@old_subscription, new_subscription) && !new_subscription.trial?
    end
end
