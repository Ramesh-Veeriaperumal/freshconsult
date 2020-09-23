module Freshfone
  module SubscriptionsHelper
    include Redis::RedisKeys
    include Redis::IntegrationsRedis

    def freshfone_trial_states?
      @freshfone_account = current_account.freshfone_account
      @freshfone_account.present? && @freshfone_account.in_trial_states?
    end

    def freshfone_subscription
      @freshfone_subscription ||= current_account.freshfone_account.subscription
      @freshfone_subscription ||= current_account.freshfone_subscription
    end

    def freshfone_trial_expired?
      @freshfone_account ||= current_account.freshfone_account
      @freshfone_account.present? && @freshfone_account.trial_expired?
    end

    def freshfone_trial?
      @freshfone_account ||= current_account.freshfone_account
      @freshfone_account.present? && (@freshfone_account.trial? || @freshfone_account.trial_exhausted?)
    end

    def freshfone_active_or_trial?
      @freshfone_account ||= current_account.freshfone_account
      @freshfone_account.present? && @freshfone_account.active_or_trial?
    end

    def freshfone_activation_requested?
      get_key(FRESHFONE_ACTIVATION_REQUEST % { account_id: current_account.id }).present?
    end
  end
end
