class ProductFeedbackValidation < ApiValidation
  attr_accessor :description, :attachment_ids, :subject, :tags

  validates :subject, data_type: { rules: String }
  validates :description, presence: true
  validates :description, data_type: { rules: String, allow_nil: false }
  validates :attachment_ids, data_type: { rules: Array, allow_nil: true }, array: { data_type: { rules: Integer } }
  validates :tags, data_type: { rules: Array, allow_nil: true }, array: { data_type: { rules: String } }

  def initialize(request_params, item, allow_string_param = nil)
    super(request_params, item, allow_string_param)
  end
end
