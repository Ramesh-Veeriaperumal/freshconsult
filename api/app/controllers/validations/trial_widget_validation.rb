class TrialWidgetValidation < ApiValidation
  attr_accessor :step
  
  validates :step, presence: true, on: :complete_step
  validates :step, data_type: { rules: String, allow_nil: false }, on: :complete_step
  validates :step, inclusion: { in: Account::SETUP_KEYS }, on: :complete_step

  def initialize(request_params, item, allow_string_param = nil)
    super(request_params, item, allow_string_param)
  end
end
