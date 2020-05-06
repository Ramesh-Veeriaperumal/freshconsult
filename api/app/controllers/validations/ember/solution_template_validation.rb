class SolutionTemplateValidation < ApiValidation
  attr_accessor :title, :description, :is_active, :is_default

  validates :title, required: true, on: :create
  validates :title, data_type: { rules: String },
                    custom_length: { maximum: SolutionConstants::TITLE_MAX_LENGTH,
                                     minimum: SolutionConstants::TITLE_MIN_LENGTH,
                                     message: :too_long_too_short }

  validates :description, required: true, on: :create
  validates :description, data_type: { rules: String }

  validates :is_active, data_type: { rules: 'Boolean' }
  validates :is_default, data_type: { rules: 'Boolean' }
end
