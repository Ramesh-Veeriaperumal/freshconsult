module ErrorConstants
  API_ERROR_CODES = {
    missing_field: ['missing_field', 'Mandatory attribute missing', 'missing', 'requester_id_mandatory',
                    'phone_mandatory', 'required_and_numericality', 'required_and_inclusion', 'required_and_data_type_mismatch',
                    'required_boolean', 'required_number', 'required_integer', 'required_date', 'required_format',
                    'fill_a_mandatory_field', 'company_id_required'],
    duplicate_value: ['has already been taken', 'already exists in the selected category', 'Email has already been taken'],
    invalid_value: ["can't be blank", 'is not included in the list', 'invalid_user'],
    datatype_mismatch: ['is not a number', 'data_type_mismatch', 'must be an integer', 'positive_number'],
    invalid_field: ['invalid_field', "Can't update user when timer is running"],
    invalid_size: ['invalid_size']
  }.freeze

  API_HTTP_ERROR_STATUS_BY_CODE = {
    duplicate_value: 409
  }.freeze

  # Reverse mapping, this will result in:
  # {'has already been taken' => :duplicate_value,
  # 'already exists in the selected category' => :duplicate_value
  # 'can't be blank' => :invalid_value
  # ...}
  API_ERROR_CODES_BY_VALUE = Hash[*API_ERROR_CODES.flat_map { |code, errors| errors.flat_map { |error| [error.to_sym, code] } }].freeze

  DEFAULT_CUSTOM_CODE = 'invalid_value'.freeze
  DEFAULT_HTTP_CODE = 400

  # http://stackoverflow.com/questions/16621073/when-to-use-symbols-instead-of-strings-in-ruby
  # Deep Symbolizing keys as this is not dynamically generated data.
  # Moreover, construction is faster & comparison is faster.
  ERROR_MESSAGES = YAML.load_file(File.join(Rails.root, 'api/lib', 'error_messages.yml')).deep_symbolize_keys![:api_error_messages].freeze
end
