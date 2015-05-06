module ApiError

	class BaseError

    API_ERROR_CODES = [
      ["has already been taken", "already_exists", 409],
      ["can't be blank", "invalid_value", 400 ],
      ["already exists in the selected category", "already_exists", 400],
      ["is not included in the list", "invalid_value", 400],
      ["invalid_field", "invalid_field",  400 ],
      ["missing_field", "missing_field", 400 ]]

	  API_ERROR_CODES_BY_VALUE = Hash[*API_ERROR_CODES.flat_map { |i| [i[0], i[1]] }]
    API_HTTP_ERROR_STATUS_BY_VALUE = Hash[*API_ERROR_CODES.flat_map { |i| [i[0], i[2]] }]

    attr_accessor :message

    def initialize(value, params_hash = {})
      @message = I18n.t("api.error_messages.#{value.to_s}", params_hash)
    end
	end

	class BadRequestError < BaseError

	  attr_accessor :code, :field, :http_code
    def initialize(attribute, value, params_hash={})
      @code = API_ERROR_CODES_BY_VALUE[value]
      @field = attribute
      @http_code = API_HTTP_ERROR_STATUS_BY_VALUE[value]
      super(value, params_hash)
    end
	end

  class RequestError < BaseError

    attr_accessor :code
    def initialize(type, params_hash = {})
      super(type, params_hash)
      @code = type.to_s
    end
  end

end