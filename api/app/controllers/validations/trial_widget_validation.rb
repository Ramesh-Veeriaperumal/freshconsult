class TrialWidgetValidation < ApiValidation
  attr_accessor :steps, :goals
  validates :steps, data_type: { rules: Array }, array: { data_type: { rules: String }, custom_inclusion: { in: TrialWidgetConstants::VALID_STEPS } }
  validates :goals, data_type: { rules: Array }, array: { data_type: { rules: String }, custom_inclusion: { in: Account::ONBOARDING_V2_GOALS } }

  def initialize(request_params, item, allow_string_param = nil)
    super(request_params, item, allow_string_param)
  end
end
