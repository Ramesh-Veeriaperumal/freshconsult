class BadRequestError < BaseError
  attr_accessor :code, :field, :http_code
  def initialize(attribute, value, params_hash = {})
    @code = ApiConstants::API_ERROR_CODES_BY_VALUE[value] || ApiConstants::DEFAULT_CUSTOM_CODE
    @field = attribute
    @http_code = ApiConstants::API_HTTP_ERROR_STATUS_BY_CODE[@code] || ApiConstants::DEFAULT_HTTP_CODE
    super(value, params_hash)
  end
end
