class BaseError
  attr_accessor :message

  API_ERROR_CODES = {
    already_exists: ['has already been taken', 'already exists in the selected category'],
    invalid_value: ["can't be blank", 'is not included in the list', 'invalid_user'],
    datatype_mismatch: ['is not a date', 'is not a number'],
    invalid_field: ['invalid_field', "Can't update user when timer is running"],
    invalid_size: ['invalid_size']
  }

  API_HTTP_ERROR_STATUS_BY_CODE = {
    already_exists: 409
  }

  # Reverse mapping, this will result in:
  # {'has already been taken' => :already_exists,
  # 'already exists in the selected category' => :already_exists
  # 'can't be blank' => :invalid_value
  # ...}
  API_ERROR_CODES_BY_VALUE = Hash[*API_ERROR_CODES.flat_map { |code, errors| errors.flat_map { |error| [error, code] } }]

  DEFAULT_CUSTOM_CODE = 'invalid_value'
  DEFAULT_HTTP_CODE = 400

  def initialize(value, params_hash = {})
    @message = I18n.t("api.error_messages.#{value}", params_hash.merge(default: value))
  end
end
