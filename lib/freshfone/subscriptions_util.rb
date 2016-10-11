module Freshfone
  module SubscriptionsUtil
    def trial?
      ff_account = load_freshfone_account
      ff_account.present? &&
        (ff_account.trial? || ff_account.trial_exhausted?)
    end

    def trial_expired?
      ff_account = load_freshfone_account
      ff_account.present? && ff_account.trial_expired?
    end

    def in_trial_states?
      ff_account = load_freshfone_account
      ff_account.present? && ff_account.in_trial_states?
    end

    def trial_exhausted?
      ff_account = load_freshfone_account
      ff_account.present? && ff_account.trial_exhausted?
    end

    def trial_numbers_empty?
      (trial_params? || trial?) && @numbers.blank?
    end

    def freshfone_subscription
      ::Account.current.freshfone_subscription if
        ::Account.current.freshfone_subscription.present?
    end

    def onboarding_enabled?
      current_account.features?(:freshfone_onboarding)
    end

    private

      def load_freshfone_account
        ::Account.current.freshfone_account
      end

      def trial_params?
        params[:subscription].present? && params[:subscription] == 'trial'
      end
  end
end
