class ProductFeedbackValidation < ApiValidation
  attr_accessor :description

  validates :description, presence: true
  validates :description, data_type: { rules: String, allow_nil: false }
end
