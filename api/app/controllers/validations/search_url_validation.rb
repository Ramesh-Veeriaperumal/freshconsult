class SearchUrlValidation < ApiValidation
  attr_accessor :query, :page

  validates :page, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param, less_than: ApiSearchConstants::MAX_PAGE + 1, custom_message: :per_page_invalid, message_options: { max_value: ApiSearchConstants::MAX_PAGE } }
  validates :query, data_type: { rules: String, required: true }

  def initialize(request_params)
    super(request_params, nil, true)
  end
end
