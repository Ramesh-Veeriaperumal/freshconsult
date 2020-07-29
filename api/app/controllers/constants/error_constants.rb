module ErrorConstants
  API_ERROR_CODES = {
    missing_field: %w(missing_field fill_a_mandatory_field),
    duplicate_value: ['has already been taken', 'already exists in the selected category', 'Email has already been taken', 'email_already_taken', 'already exists in the selected category.', 'duplicate_choices', 'duplicate_label_nested_fields', 'duplicate_labels_ticket_field'],
    exceeded_limit: ['exceeded_limit'],
    under_limit: ['min_elements'],
    invalid_field: ['invalid_field', 'invalid_choices_field'],
    datatype_mismatch: %w(datatype_mismatch per_page_invalid array_datatype_mismatch limit_invalid),
    count_mismatch: %w[count_mismatch],
    invalid_size: ['invalid_size'],
    incompatible_field: ['incompatible_field'],
    inaccessible_field: ['inaccessible_field'],
    inaccessible_value: ['inaccessible_value'],
    unable_to_perform: ['unable_to_perform'],
    access_denied: ['access_denied'],
    traffic_cop_alert: ['traffic_cop_alert'],
    unresolved_child: ['unresolved_child'],
    facebook_user_blocked: ['facebook_user_blocked'],
    max_limit_reached: ['dashboard_limit_exceeded', 'announcement_limit_exceeded', 'widget_limit_exceeded'],
    undo_send_enqueued_alert: ['undo_send_enqueued_alert'],
    undo_send_enqueued_agent_alert: ['undo_send_enqueued_agent_alert'],
    twitter_app_blocked: ['twitter_write_access_blocked'],
    exceeded_total_file_field_attachments_size: ['exceeded_total_file_field_attachments_size'],
    non_unique_file_field_attachment_ids: ['non_unique_file_field_attachment_ids'],
    invalid_token: ['token_expired']
  }.freeze

  API_HTTP_ERROR_STATUS_BY_CODE = {
    duplicate_value: 409,
    access_denied: 403,
    twitter_app_blocked: 400,
    unauthorized: 401
  }.freeze

  # Reverse mapping, this will result in:
  # {'has already been taken' => :duplicate_value,
  # 'already  exists in the selected category' => :duplicate_value
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
