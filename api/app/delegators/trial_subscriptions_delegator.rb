class TrialSubscriptionsDelegator < BaseDelegator
  attr_accessor :latest_trial_subscription, :trial_plan

  validate :trial_subscription_absence, :check_last_trial_subscription, :check_for_valid_plan_name, on: :create
  validate :trial_subscription_presence, on: :cancel

  def initialize(record, options = {})
    super(record, options)
    @latest_trial_subscription ||= Account.current.trial_subscriptions.last
    @trial_plan = record.trial_plan if record.present? && record.trial_plan.present?
  end

  def trial_subscription_presence
    if Account.current.active_trial.blank?
      errors[:trial_plan] << 'No trial subscriptions are currently active'
    end
  end

  def trial_subscription_absence
    if latest_trial_subscription.present? && latest_trial_subscription.active?
      errors[:trial_plan] << 'Trial subscription already active'
    end
  end

  def check_last_trial_subscription
    if latest_trial_subscription.present? && !latest_trial_subscription.active? &&
       (latest_trial_subscription.days_left_for_next_trial > 0)
      errors[:trial_plan] << 'Cannot activate trial before waiting period'
    end
  end

  def check_for_valid_plan_name
    unless SubscriptionPlan.current_plan_names_from_cache.include? trial_plan
      errors[:trial_plan] << "Invalid plan name #{trial_plan}"
    end
  end
end
