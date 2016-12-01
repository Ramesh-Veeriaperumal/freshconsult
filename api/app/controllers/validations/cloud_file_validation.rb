class CloudFileValidation < ApiValidation

  attr_accessor :url, :filename, :application_id

  validates :url, required: true, data_type: { rules: String }
  validates :filename, required: true, data_type: { rules: String }
  validates :application_id, required: true, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false, ignore_string: :allow_string_param }

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
  end
end
