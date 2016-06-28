module ErrorConstants
  API_ERROR_CODES = {
    missing_field: %w(missing_field fill_a_mandatory_field),
    duplicate_value: ['has already been taken', 'already exists in the selected category.', 'Email has already been taken', 'email_already_taken'],
    invalid_field: ['invalid_field'],
    datatype_mismatch: %w(datatype_mismatch per_page_invalid array_datatype_mismatch),
    invalid_size: ['invalid_size'],
    incompatible_field: %w(incompatible_field multiple_portals_required cant_set_company_ids cant_set_art_type attribute_not_required),
    inaccessible_field: ['inaccessible_field', 'require_feature_for_attribute', 'require_feature_to_suppport_the_request'],
    inaccessible_value: ['inaccessible_value']
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
  ERROR_MESSAGES = YAML.load_file(File.join(Rails.root, 'api/lib', 'error_messages.yml'))['api_error_messages'].symbolize_keys!.freeze
end
