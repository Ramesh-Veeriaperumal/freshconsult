class BadRequestError < BaseError
  attr_accessor :code, :field, :http_code
  def initialize(attribute, value, params_hash = {})
    placeholders = (params_hash || {}).key?(attribute) ? params_hash[attribute] : params_hash
    @code = ErrorConstants::API_ERROR_CODES_BY_VALUE[value] || ErrorConstants::DEFAULT_CUSTOM_CODE
    @field = attribute
    @http_code = ErrorConstants::API_HTTP_ERROR_STATUS_BY_CODE[@code] || ErrorConstants::DEFAULT_HTTP_CODE
    super(value, placeholders) # params hash is used for sending param to translation.
  end
end
