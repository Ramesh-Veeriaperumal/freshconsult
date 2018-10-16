class TrialSubscriptionsValidation < ApiValidation
  FEATURES_LIST = Set[*(UsageMetrics::Features::FEATURES_LIST + 
    UsageMetrics::Features::FEATURES_TRUE_BY_DEFAULT)]
  attr_accessor :trial_plan, :features

  validates :trial_plan, presence: true, on: :create
  validates :trial_plan, data_type: { rules: String, allow_nil: false }, on: :create
  validates :features, required: true, data_type: { rules: Array }, 
    custom_length: { 
      maximum: UsageMetrics::Features::MAX_FEATURES_COUNT_PER_REQUEST 
    },
    array: {
      custom_inclusion: { in: FEATURES_LIST }
    }, on: :usage_metrics
end
