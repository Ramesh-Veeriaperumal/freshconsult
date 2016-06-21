class SurveyValidation < ApiValidation
  attr_accessor :rating, :feedback, :custom_ratings, :custom_survey_enabled, :allowed_custom_choices, :allowed_default_choices

  validates :rating, custom_inclusion: { in:  proc { |x|  x.allowed_default_choices }, detect_type: true, required: true }, if: -> { custom_survey_enabled }
  validates :rating, custom_inclusion: { in:  SurveyConstants::CLASSIC_RATINGS, detect_type: true, required: true }, unless: -> { custom_survey_enabled }
  validates :feedback, data_type: { rules: String }
  validates :custom_ratings, data_type: { rules: Hash }, hash: { custom_inclusion: { in: proc { |x| x.allowed_custom_choices }, detect_type: true } }

  def initialize(request_params, item, custom_survey_enabled, allowed_custom_choices, allowed_default_choices)
    @custom_survey_enabled = custom_survey_enabled
    @allowed_custom_choices = allowed_custom_choices
    @allowed_default_choices = allowed_default_choices
    super(request_params, item)
  end

  def attributes_to_be_stripped
    SurveyConstants::ATTRIBUTES_TO_BE_STRIPPED
  end
end
