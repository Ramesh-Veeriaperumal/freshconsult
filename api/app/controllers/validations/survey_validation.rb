class SurveyValidation < ApiValidation
  attr_accessor :ratings, :feedback, :allowed_custom_choices, :allowed_default_choices

  validates :ratings, required: true, data_type: { rules: Hash }, hash: { validatable_fields_hash: proc { |x| x.construct_hash_field_validations } }
  validates :feedback, data_type: { rules: String }

  def initialize(request_params, item, allowed_custom_choices, allowed_default_choices)
    @allowed_custom_choices = allowed_custom_choices
    @allowed_default_choices = allowed_default_choices
    super(request_params, item)
  end

  def attributes_to_be_stripped
    SurveyConstants::ATTRIBUTES_TO_BE_STRIPPED
  end

  def construct_hash_field_validations
    fields_hash = { default_question: { custom_inclusion: { in: proc { |x| x.allowed_default_choices }.call(self), detect_type: true, required: true } } }
    ratings.keys.each { |field| fields_hash[field.to_sym] = { custom_inclusion: { in: proc { |x| x.allowed_custom_choices }.call(self), detect_type: true } } unless field == 'default_question' }
    fields_hash
  end
end
