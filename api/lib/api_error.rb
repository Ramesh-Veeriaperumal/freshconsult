module ApiError

	class BaseError

    API_ERROR_CODES = [
      ["has already been taken", "already_exists", I18n.t('api.error_messages.duplicate'), 409],
      ["can't be blank", "invalid_value", I18n.t('api.error_messages.blank'), 400 ],
      ["invalid_field", "invalid_field", I18n.t('api.error_messages.invalid_field'), 400 ],
      ["missing_field", "missing_field", I18n.t('api.error_messages.missing_field'), 400 ]]

	  API_ERROR_CODES_BY_VALUE = Hash[*API_ERROR_CODES.map { |i| [i[0], i[1]] }.flatten]
	  API_ERROR_MESSAGES_BY_VALUE = Hash[*API_ERROR_CODES.map { |i| [i[0], i[2]] }.flatten]
    API_HTTP_ERROR_STATUS_BY_VALUE = Hash[*API_ERROR_CODES.map { |i| [i[0], i[3]] }.flatten]

    attr_accessor :message, :http_code	

    def initialize(message, code)
      @message = message
      @http_code = code
    end
	end

	class BadRequestError < BaseError

	  attr_accessor :code, :field
    def initialize(attribute, value)
      @code = API_ERROR_CODES_BY_VALUE[value]
      @field = attribute
      super(API_ERROR_MESSAGES_BY_VALUE[value], API_HTTP_ERROR_STATUS_BY_VALUE[value])
    end
	end

end