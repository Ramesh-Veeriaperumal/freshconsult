class TrialSubscriptionsValidation < ApiValidation
  attr_accessor :trial_plan

  validates :trial_plan, presence: true, on: :create
  validates :trial_plan, data_type: { rules: String, allow_nil: false }, on: :create
end
