class TrialSubscription < ActiveRecord::Base
  TRIAL_STATUSES = {
    active: 0,
    inactive: 1,
    cancelled: 2
  }.freeze

  RESULTS = {
    upgraded: 0,
    downgraded: 1
  }.freeze

  TRIAL_INTERVAL_IN_DAYS = 90
  TRIAL_PERIOD_LENGTH = 21
  ACTION_TO_PLAN_CHANGE_CLASS = {
    activate: TrialSubscription::PlanUpgrade,
    cancel: TrialSubscription::PlanDowngrade
  }.freeze

  TRIAL_SUBSCRIPTION_LP_FEATURE = :trial_subscription
end
