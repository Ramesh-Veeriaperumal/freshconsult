module Freshfone
  class SubscriptionObserver < ActiveRecord::Observer
    observe Freshfone::Subscription

    def after_update(subscription)
      if usage_changed?(subscription)
        trigger_end_call(subscription)
        freshfone_trial_exhaust(subscription)
      end
    end

    private

      def usage_changed?(subscription)
        subscription.inbound_changed? ||
          subscription.outbound_changed?
      end

      def inbound_exceeded?(subscription)
        subscription.inbound_changed? &&
          subscription.inbound_usage_exceeded?
      end

      def outbound_exceeded?(subscription)
        subscription.outbound_changed? &&
          subscription.outbound_usage_exceeded?
      end

      def trigger_end_call(subscription)
        if inbound_exceeded?(subscription)
          Freshfone::EndTrialCallWorker.perform_async(call_type: Freshfone::Call::CALL_TYPE_HASH[:incoming])
        elsif outbound_exceeded?(subscription)
          Freshfone::EndTrialCallWorker.perform_async(call_type: Freshfone::Call::CALL_TYPE_HASH[:outgoing])
        end
      end

      def freshfone_trial_exhaust(subscription)
        freshfone_account = subscription.freshfone_account
        return if freshfone_account.blank?
        subscription.freshfone_account.trial_exhaust if subscription.trial_limits_breached?
      end
  end
end