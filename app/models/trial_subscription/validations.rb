class TrialSubscription < ActiveRecord::Base
  validates :account, presence: true
  validates :actor, presence: true # the one who activates trial subscription
  validates :status, inclusion: TRIAL_STATUSES.values
  validates :result, inclusion: RESULTS.values, if: proc { |trial_subscription| trial_subscription.result.present? }
  validate :no_active_trial_subscriptions_exists, on: :create

  validates :from_plan, presence: true
  validates :trial_plan, presence: true

  private

    def no_active_trial_subscriptions_exists
      errors.add(:status, 'Account already has an active trial subscription') if account.active_trial.present?
    end
end
