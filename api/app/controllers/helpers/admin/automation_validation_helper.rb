module Admin::AutomationValidationHelper
  include Admin::AutomationConstants

  def initialize_params(request_params, valid_attributes)
    format_params = {}
    @invalid_attributes = []
    request_params.each do |param|
      next if param[:field_name].blank?
      if valid_attributes.include?(param[:field_name].to_sym)
        format_params[param[:field_name]] ||= []
        format_params[param[:field_name]] << param
      end
    end
    format_params
  end

  def errors_for_invalid_attributes
    @invalid_attributes.each do |invalid_param|
      unexpected_parameter(invalid_param)
    end
    false
  end

  def event_validation(expected, actual)
    case expected[:field_type]
      when :dropdown
        if expected[:expect_from_to].present?
          validate_event_from_to(expected, actual)
        else
          validate_event_value(expected, actual)
        end
      else #label
        validate_label_field_type(expected, actual)
    end
  end

  def condition_validation(expected, actual)
    operator_list = if supervisor_rule? && expected[:field_type] == :email && !Account.current.supervisor_with_text_field_enabled?
      FIELD_TYPE[expected[:"#{field_type}_supervisor"]]
    else
      FIELD_TYPE[expected[:field_type]]
    end
    operator = operator_list.include?(actual[:operator].to_sym) if actual[:operator].present?
    case_sensitive_validation(expected, actual) if actual.has_key?(:case_sensitive)
    if operator.present?
      checkbox_value = NO_VALUE_EXPECTING_OPERATOR.include?(actual[:operator].to_sym)
      text_field_value = SINGLE_VALUE_EXPECTING_OPERATOR.include?(actual[:operator].to_sym)
      expected_data_type = text_field_value ? 'single' : 'multiple'
      validate_condition_value(expected, actual, !checkbox_value, expected_data_type)
    else
      missing_field_error(expected[:name], 'operator') unless actual.key?(:operator)
      not_included_error(:"#{expected[:name]}[operator]", operator_list) if actual.key?(:operator)
    end
  end

  def action_validation(expected, actual)
    case expected[:field_type]
      when :dropdown, :text
        validate_action_value(expected, actual)
      when :webhook
        validate_webhook(expected, actual)
      when :email
        validate_send_email(expected, actual)
      when :add_note_type
        validate_notify_emails(expected, actual)
      when :forward_note
        validate_forward_note(expected, actual)
      else #label
        validate_label_field_type(expected, actual)
    end
  end

  def case_sensitive_validation(expected, actual)
    if expected[:field_type] == :text
      has_key = actual.has_key?(:case_sensitive)
      missing_field_error(expected[:name], 'case_sensitive') unless has_key
      return unless has_key

      case_sensitive = BOOLEAN.include?(actual[:case_sensitive])
      invalid_data_type(":case_sensitive", BOOLEAN.join(', '), actual[:case_sensitive]) unless case_sensitive
    else
      case_sensitive_not_allowed(actual[:field_name])
    end
  end

  def add_watcher_feature
    unless Account.current.add_watcher_enabled?
      errors[:"watcher[:condition]"] << :require_feature
      error_options.merge!(:"watcher[:condition]" => {feature: :add_watcher,
                                                      code: :access_denied})
    end
  end

  def multi_product_feature
    unless Account.current.multi_product_enabled?
      errors[:"multi_product[:condition]"] << :require_feature
      error_options.merge!(:"multi_product[:condition]" => {feature: :multi_product,
                                                            code: :access_denied})
    end
  end

  def shared_ownership_feature
    unless Account.current.shared_ownership_enabled?
      errors[:"shared_ownership[:condition]"] << :require_feature
      error_options.merge!(:"shared_ownership[:condition]" => {feature: :shared_ownership,
                                                               code: :access_denied})
    end
  end

  def multiple_business_hours?
    unless Account.current.multiple_business_hours_enabled?
      errors[:"multiple_business_hours[:condition]"] << :require_feature
      error_options.merge!(:"multiple_business_hours[:condition]" => {feature: :multiple_business_hours,
                                                               code: :access_denied})
    end
  end

  def system_observer_events
    unless Account.current.system_observer_events_enabled?
      errors[:condition] << :require_feature
      error_options.merge!(condition: {feature: :system_observer_events,
                                       code: :access_denied})
    end
  end

  def custom_survey_feature
    unless Account.current.any_survey_feature_enabled_and_active?
      errors[:"any_survey[:condition]"] << :require_feature
      error_options.merge!(:"any_survey[:condition]" => {feature: :survey, # I am not sure about the feature please check
                                                         code: :access_denied})
    end
  end

  def validate_event_from_to(expected, actual)
    if !(actual.key?(:from) && actual.key?(:to))
      missing_field_error(expected[:name], :'from/to')
    else
      is_expected_data_type = valid_event_data_type?(expected, actual[:from]) && 
                              valid_event_data_type?(expected, actual[:to])
      expected_type = ERROR_MESSAGE_DATA_TYPE_MAP[expected[:data_type]]
      invalid_data_type(expected[:name], expected_type, :invalid) unless is_expected_data_type
    end
    if actual.key?(:value)
      unexpected_value_for_attribute(expected[:name], :value)
    end
  end

  def validate_event_value(expected, actual)
    if actual[:value].blank?
      missing_field_error(expected[:name], :value)
    else
      is_expected_data_type = valid_event_data_type?(expected, actual[:value])
      expected_type = ERROR_MESSAGE_DATA_TYPE_MAP[expected[:data_type]]
      invalid_data_type(expected[:name], expected_type, :invalid) unless is_expected_data_type
    end
    if actual.key?(:from) || actual.key?(:to)
      unexpected_value_for_attribute(expected[:name], :'from/to')
    end
  end

  def validate_action_value(expected, actual)
    if actual.key?(:value)
      is_expected_data_type = valid_action_data_type?(expected, actual[:value])
      expected_type = expected[:multiple] ? 'list' : ERROR_MESSAGE_DATA_TYPE_MAP[expected[:data_type]]
      invalid_data_type(expected[:name], expected_type, 'invalid') unless is_expected_data_type
    else
      missing_field_error(expected[:name], 'value')
    end
  end

  def validate_condition_value(expected, actual, expecting_value, expected_data_type)
    if expecting_value
      if actual.key?(:value)
        is_expected_data_type = valid_condition_data_type?(expected, actual[:value], expected_data_type)
        unexpected_parameter(":#{expected[:name]}[:value]") unless is_expected_data_type
        validate_email(expected[:name], actual[:value]) if expected[:field_type] == :email && is_expected_data_type &&
                                                           EMAIL_VALIDATOR_OPERATORS.include?(actual[:operator].to_sym)
        validate_date(expected[:name], actual[:value]) if expected[:field_type] == :date && is_expected_data_type
        validate_business_hours(expected[:name], actual) if BUSINESS_HOURS_FIELDS.include?(expected[:name])
      else
        missing_field_error(expected[:name], 'value')
      end
    else
      unexpected_parameter('value') if actual.key?(:value)
    end
  end

  def validate_label_field_type(expected, actual)
    if actual[:from].present? || actual[:to].present? || actual[:value].present?
      invalid_values = []
      invalid_values << :from if actual.key? :from
      invalid_values << :to if actual.key? :to
      invalid_values << :value if actual.key? :value
      unexpected_value_for_attribute(expected[:name], invalid_values.join(','))
    end
  end

  def validate_webhook(expected, actual)
    if (actual.keys - WEBHOOK_PERMITTED_PARAMS).present?
      invalid_value_list(expected[:name], WEBHOOK_PERMITTED_PARAMS, message = :invalid_attribute_for_key)
    end
    missing_field_error(expected[:name], :url) unless actual.key?(:url)
    validate_auth_header(expected[:name], actual[:auth_header]) if actual.key?(:auth_header)

    headers = actual[:custom_headers]
    invalid_data_type(:"#{expected[:name]}[:custom_headers]", :JSON, :invalid) if actual.key?(:custom_headers) && !headers.is_a?(Hash)
    validate_based_on_http_method(actual[:request_type].to_sym, expected, actual)

  end

  def validate_based_on_http_method(method_name, expected, actual)
    case method_name
      when :GET, :PATCH, :DELETE
        unexpected_parameter(:"#{expected[:name]}[:content_layout]") if actual.key? :content_layout
        unexpected_parameter(:"#{expected[:name]}[:content_type]") if actual.key? :content_type
        unexpected_parameter(:"#{expected[:name]}[:content]") if actual.key? :content
      when :POST, :PUT
        missing_field_error(expected[:name], :content_type) unless actual.key? :content_type
        missing_field_error(expected[:name], :content_layout) unless actual.key? :content_layout
        missing_field_error(expected[:name], :content) unless actual.key? :content
        if actual.key?(:content) && actual.key?(:content_layout) && actual[:content_type].is_a?(String)
          check_content_type(actual[:content_type], actual[:content_layout], actual[:content], expected[:name])
        end
      else
        actual.key?(:request_type) ? unexpected_parameter(:"#{expected[:name]}[:request_type]") :
            missing_field_error(expected[:name], :request_type)
    end
  end
  def validate_notify_emails(expected,actual)
    missing_field_error(expected[:name], :note_body) unless actual.key? :note_body
    invalid_data_type(:"#{expected[:name]}[:note_body]",:String,:invalid) if actual[:note_body].present? && !actual[:note_body].is_a?(String)
    invalid_data_type(:"#{expected[:name]}[:notify_agents]", :array, :invalid) if actual[:notify_agents].present? && !actual[:notify_agents].is_a?(Array)
    if (actual.key? (:notify_agents)) && (actual[:notify_agents].is_a?(Array))
      actual[:notify_agents].each_with_index do |agent_id,index|
        invalid_data_type(:"#{expected[:name]}[:notify_agents][index_#{index}]", :number, :invalid) unless agent_id.is_a?(Integer)
      end
    end
  end

  def validate_send_email(expected, actual)
    unexpected_parameter(:"#{expected[:name]}[:email_subject]") if actual[:email_subject].present? && !actual[:email_subject].is_a?(String)
    unexpected_parameter(:"#{expected[:name]}[:email_body]") if actual[:email_body].present? && !actual[:email_body].is_a?(String)
    missing_field_error(expected[:name], :email_subject) unless actual.key? :email_subject
    missing_field_error(expected[:name], :email_body) unless actual.key? :email_body

    if expected[:name] == :send_email_to_group || expected[:name] == :send_email_to_agent
      missing_field_error(actual[:name], :email_to) unless actual.key? :email_to
      invalid_data_type(:"#{expected[:name]}[:email_to]", :number, :invalid) unless actual[:email_to].is_a?(Integer)
    else
      unexpected_parameter(:"#{expected[:name]}[:email_to]") if actual.key? :email_to
    end
  end

  def validate_forward_note(expected, actual)
    missing_field_error(actual[:name], :fwd_to) unless actual.key? :fwd_to
    [:fwd_to, :fwd_cc, :fwd_bcc].each do |field_name|
      next unless actual[field_name].present?
      actual[field_name].is_a?(Array) ? validate_email(field_name, actual[field_name]) : invalid_data_type(:"#{expected[:name]}[#{field_name}", :array, :invalid)
    end
    invalid_data_type(:"#{expected[:name]}[:fwd_note_body]", :string, :invalid) if actual[:fwd_note_body].present? && !actual[:fwd_note_body].is_a?(String)
    invalid_data_type(:"#{expected[:name]}[:show_quoted_text]", :boolean, :invalid) if actual[:show_quoted_text].present? && !actual[:show_quoted_text].in?([true, false])
    missing_field_error(actual[:name], :'fwd_note_body/show_quoted_text') if actual[:fwd_note_body].blank? && !actual[:show_quoted_text]
  end

  def validate_email(name, emails)
    emails = *emails
    invalid_list = []
    emails.each do |email|
      invalid_list << email unless email.match(ApiConstants::EMAIL_REGEX)
    end
    invalid_email_addresses(name, invalid_list) if invalid_list.present?
  end

  def validate_date(name, date)
    date = date.split('-')
    unexpected_parameter(name) unless Date.valid_date?(date[0].to_i, date[1].to_i, date[2].to_i)
  end

  def valid_event_data_type?(expected, value)
    data_type_class = expected[:data_type].to_s.constantize
    is_expected_data_type = value.is_a?(data_type_class)
    is_expected_data_type || none_value?(value, EVENT_NONE_FIELDS.include?(expected[:name])) || 
      any_value?(value, EVENT_ANY_FIELDS.include?(expected[:name]))
  end

  def valid_action_data_type?(expected, value)
    data_type_class = expected[:data_type].to_s.constantize
    is_expected_data_type = value.is_a?(data_type_class)
    is_expected_data_type || none_value?(value, ACTION_NONE_FIELDS.include?(expected[:name]))
  end

  def valid_condition_data_type?(expected, value, expected_data_type)
    data_type_class = expected[:data_type].to_s.constantize
    is_expected_data_type = (value.is_a?(Array) && value.all? {|x| x.is_a?(data_type_class)}) ||
                            value.is_a?(expected_data_type == 'multiple' ? Array : data_type_class)
    is_expected_data_type || none_value?(value, CONDITION_NONE_FIELDS.include?(expected[:name]))
  end

  def validate_business_hours(name, actual)
    if actual.key?(:business_hours_id)
      multiple_business_hours?
      missing_field_error(name, :business_hours_id) if actual[:business_hours_id].blank?
      invalid_data_type(name, :Number, :invalid) unless actual[:business_hours_id].is_a?(Integer)
    end
  end

  def none_value?(value, is_none_field)
    value == '' && is_none_field
  end

  def any_value?(value, is_any_field)
    value == '--' && is_any_field
  end

  def check_content_type(type, layout, content, field_name)
    case type.to_sym
      when :JSON
        unexpected_parameter(:"#{field_name}[:content_layout]") unless layout != 1 || layout != 2
        invalid_data_type(:"#{field_name}[:content]", type.to_sym, :invalid) unless content.is_a?(Hash)
      when :XML
        unexpected_parameter(:"#{field_name}[:content_layout]") unless layout != 2
        invalid_data_type(:"#{field_name}[:content]", type.to_sym, :invalid) unless content.is_a?(String)
      when :'X-FORM-URLENCODED'
        unexpected_parameter(:"#{field_name}[:content_layout]") unless layout != 1
        invalid_data_type(:"#{field_name}[:content]", type.to_sym, :invalid) unless content.is_a?(Hash)
      else
        unexpected_parameter(:"#{field_name}[:content_type]")
    end
  end

  def validate_auth_header(field_name, header)
    not_included_error(:"#{field_name}[:auth_header]", WEBHOOK_AUTH_HEADER_KEY) if header.blank?
    if header.is_a?(Hash)
      invalid_auth_keys = (header.keys - (WEBHOOK_AUTH_HEADER_KEY & header.keys))
      username, password, api_key = header[:username], header[:password], header[:api_key]
      if invalid_auth_keys.present?
        unexpected_value_for_attribute(:"#{field_name}[:auth_header]", invalid_auth_keys.join(','))
      elsif username.present? && api_key.present?
        unexpected_parameter(:"#{field_name}[:auth_header]", :webhook_auth_header_error)
      elsif username.present? && !password.present?
        missing_field_error(:"#{field_name}[:auth_header]", :password)
      else
        invalid_data_type(:"#{field_name}[:auth_header][:api_key]",
                          :String, :invalid) if api_key.present? && !api_key.is_a?(String)
      end
    else
      invalid_data_type(:"#{field_name}[:auth_header]", :JSON, :invalid)
    end
  end

  def unexpected_value_for_attribute(name, value, message = :unexpected_parameter_error)
    errors[construct_key(name)] << message
    error_message = {}
    error_message[construct_key(name)] = {name: name, value: value}
    error_options.merge!(error_message)
  end

  def unexpected_parameter(name, message = :invalid_field )
    errors[construct_key(name)] << message
  end

  def missing_field_error(name, value)
    errors[construct_key(name)] << :expecting_value_for_event_field
    error_message = {}
    error_message[construct_key(name)] = {name: name, value: value}
    error_options.merge!(error_message)
  end

  def invalid_data_type(name, expected_type, actual_type)
    errors[construct_key(name)] << :invalid_data_type
    error_message = {}
    error_message[construct_key(name)] = {expected_type: expected_type, actual_type: actual_type}
    error_options.merge!(error_message)
  end

  def not_included_error(name, expected_values, message = :not_included)
    errors[construct_key(name)] << message
    error_message = {}
    error_message[construct_key(name)] = {list: expected_values.join(',')}
    error_options.merge!(error_message)
  end

  def invalid_condition_set(set)
    errors[:"#{type_name}[:#conditions_set_#{set}]"] << :expecting_previous_condition_set
    error_message = {}
    error_message[:"#{type_name}[:#conditions_set_#{set}]"] = {current: :"conditions_set_#{set}", previous: :"conditions_set_#{set - 1}"}
    error_options.merge!(error_message)
  end

  def invalid_value_list(name, list, message = :invalid_list)
    errors[construct_key(name)] << message
    error_message = {}
    error_message[construct_key(name)] = {list: list.join(',')}
    error_options.merge!(error_message)
  end

  def invalid_email_addresses(name, list)
    errors[construct_key(name)] << :invalid_email_list
    error_message = {}
    error_message[construct_key(name)] = {list: list.join(',')}
    error_options.merge!(error_message)
  end

  def case_sensitive_not_allowed(name)
    errors[construct_key(name)] << :case_sensitive_not_allowed
    error_message = {}
    error_message[construct_key(name)] = {name: name}
    error_options.merge!(error_message)
  end

  def construct_key(name)
    field_position.present? ? :"#{type_name}[:#{name}][#{field_position}]" : :"#{type_name}[:#{name}]"
  end

  def dispatcher_rule?
    rule_name = VAConfig::RULES_BY_ID[rule_type.to_i]
    rule_name == :dispatcher
  end

  def observer_rule?
    rule_name = VAConfig::RULES_BY_ID[rule_type.to_i]
    rule_name == :observer
  end

  def supervisor_rule?
    rule_name = VAConfig::RULES_BY_ID[rule_type.to_i]
    rule_name == :supervisor
  end

  def merge_to_parent_errors(validation)
    validation.errors.to_h.each_pair do |key, value|
      errors[key] << value
    end
  end
end
