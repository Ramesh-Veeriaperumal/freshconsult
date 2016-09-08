class AttachmentValidation < ApiValidation
  attr_accessor :user_id, :content

  validates :user_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false, ignore_string: :allow_string_param }
  validates :content, required: true, data_type: { rules: ApiConstants::UPLOADED_FILE_TYPE, allow_nil: false }

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
  end
end
