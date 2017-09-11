class ProductFeedbackValidation < ApiValidation
  attr_accessor :description, :attachment_ids

  validates :description, presence: true
  validates :description, data_type: { rules: String, allow_nil: false }
  validates :attachment_ids, data_type: { rules: Array, allow_nil: true }, array: { data_type: { rules: Integer } }
end
