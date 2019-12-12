class TrialWidgetValidation < ApiValidation
  attr_accessor :step, :goals

  validates :step, data_type: { rules: String, allow_nil: false }, on: :complete_step
  validates :step, inclusion: { in: Account::SETUP_KEYS, allow_blank: true }, on: :complete_step
  validate :validate_goals, on: :complete_step

  def initialize(request_params, item, allow_string_param = nil)
    super(request_params, item, allow_string_param)
  end

  def validate_goals
    errors.add(:goals, :invalid) if goals && (!goals.is_a?(Array) || goals.detect { |d| !Account::ONBOARDING_V2_GOALS.include?(d) })
  end
end
