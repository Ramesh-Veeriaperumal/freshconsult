class BadRequestError < BaseError
  attr_accessor :code, :field, :http_code
  def initialize(attribute, value, params_hash = {})
    placeholders = (params_hash || {}).key?(attribute) ? params_hash[attribute] : params_hash
    @code = API_ERROR_CODES_BY_VALUE[value] || DEFAULT_CUSTOM_CODE
    @field = attribute
    @http_code = API_HTTP_ERROR_STATUS_BY_CODE[@code] || DEFAULT_HTTP_CODE
    super(value, placeholders) # params hash is used for sending param to translation.
  end
end
