module Admin::Automation::ConstructResponseData
  include Va::Constants
  include Admin::AutomationConstants

  def construct_marketplace_app(action)
    action_hash = action.to_hash.dup.symbolize_keys
    action_hash[:field_name] = INTEGRATION_API_NAME_MAPPING[action_hash[:name].to_sym]
    action_hash.delete :name
    action_hash.delete :value
    action_hash.delete :include_va_rule
    action_hash
  end

  def construct_webhook(action)
    action = action.deep_symbolize_keys
    action_hash = default_webhook_data(action)
    action_hash[:content_type] = WEBHOOK_CONTENT_TYPES[action[:content_type]].to_s
    action_hash[:content_layout] = action[:content_layout].to_s
    action_hash[:content] = webhook_content(action) if action[:params].present?
    action_hash[:custom_headers] = (action[:custom_headers].to_hash rescue action[:custom_headers])
    action_hash.select! { |_, value| value.present? }
    construct_auth_header(action, action_hash)
    action_hash
  end

  def default_webhook_data(action)
    {
      request_type: WEBHOOK_REQUEST_TYPES[action[:request_type]].to_s,
      url: action[:url],
      field_name: action[:name]
    }
  end

  def webhook_content(action)
    if action[:content_layout].to_s == '1' || action[:content_type] == '2'
      begin
        JSON.parse(action[:params])
      rescue StandardError
        action[:params]
      end
    else
      action[:params].to_s
    end
  end

  def construct_auth_header(action, action_hash)
    if action.key?(:need_authentication)
      action_hash.delete :need_authentication
      action_hash[:auth_header] = {}
      action_hash[:auth_header][:username] = action[:username] if action[:username].present?
      action_hash[:auth_header][:password] = MASKED_FIELDS[:password] if action[:password].present?
      action_hash[:auth_header][:api_key] = action[:api_key] if action[:api_key].present?
    end
  end

  def add_operator_for_nested_field(data)
    data.symbolize_keys!
    nested_fields = data[:nested_fields]
    return if nested_fields.blank?
    NESTED_LEVEL_COUNT.times do |level_no|
      level_name = :"level#{level_no + 2}"
      level_data = nested_fields[level_name]
      level_data[:operator] ||= :is if level_data.present?
    end
  end

  def support_for_old_operators(data)
    data.symbolize_keys!
    # convert value to array
    if data[:operator].is_a?(String) && NEW_ARRAY_VALUE_OPERATOR_MAPPING.key?(data[:operator].to_sym)
      data[:value] = *data[:value]
      data[:operator] = NEW_ARRAY_VALUE_OPERATOR_MAPPING[data[:operator].to_sym]
    end
  end

  def convert_supervisor_operators(data)
    data.symbolize_keys!
    name = (data[:field_name].to_sym rescue data[:field_name])
    return if !custom_dropdown_fields.include?(name) && !SUPERVISOR_OPERATOR_CONVERSION_FIELD.include?(name)

    # change is to in, is_not to not_in
    if data[:operator].is_a?(String) && SUPERVISOR_OPERATOR_FROM_TO.key?(data[:operator].to_sym)
      data[:value] = *data[:value]
      data[:operator] = SUPERVISOR_OPERATOR_FROM_TO[data[:operator].to_sym]
    end
  end

  def delete_value_for_old_rule(data)
    data.symbolize_keys!
    data.delete :value if data[:operator].is_a?(String) && NO_VALUE_EXPECTING_OPERATOR.include?(data[:operator].to_sym)
  end

  def transform_value(data)
    data.symbolize_keys!
    name = data[:field_name].to_sym
    all_fields = custom_number_fields + custom_decimal_fields + DEFAULT_FIELD_VALUE_CONVERTER + custom_checkbox_fields
    return unless all_fields.include?(name)
    change_value(name, data)
  end

  def change_value(name, data)
    type = field_type(name)
    EVENT_VALUES_KEY.each do |key|
      next unless data.key?(key)
      if data[key].is_a?(Array)
        data[key].map! do |value|
          ANY_NONE_VALUES.include?(value) ? value : convert_value(value, type)
        end
      else
        data[key] = ANY_NONE_VALUES.include?(data[key]) ? data[key] : convert_value(data[key], type)
        data[key] = *data[key] if ARRAY_VALUE_EXPECTING_FIELD.include?(name)
      end
    end
  end

  def field_type(name)
    type = :Integer if custom_number_fields.include?(name) || custom_checkbox_fields.include?(name)
    type = :Float if custom_decimal_fields.include?(name)
    type || DEFAULT_FIELD_VALUE_TYPE[name]
  end

  def convert_value(value, type)
    case type
    when :Integer
      value.to_s.to_i
    when :Float
      value.to_s.to_f
    else
      value.to_s
    end
  end

  def custom_dropdown_fields
    field_type = proc { |field| field.field_type == 'custom_dropdown' }
    field_name = proc { |field| TicketDecorator.display_name(field.name).to_sym }
    @custom_dropdown_fields ||= current_account.ticket_fields.select(&field_type).map(&field_name)
  end

  def custom_checkbox_fields
    field_type = proc { |field| field.field_type == 'custom_checkbox' }
    field_name = proc { |field| TicketDecorator.display_name(field.name).to_sym }
    @custom_checkbox_fields ||= custom_ticket_fields_from_cache.select(&field_type).map(&field_name)
  end

  def custom_number_fields
    field_type = proc { |field| field.field_type == 'custom_number' }
    field_name = proc { |field| TicketDecorator.display_name(field.name).to_sym }
    @custom_number_field ||= custom_ticket_fields_from_cache.select(&field_type).map(&field_name)
  end

  def custom_decimal_fields
    field_type = proc {  |field| field.field_type == 'custom_decimal' }
    field_name = proc { |field| TicketDecorator.display_name(field.name).to_sym }
    @custom_decimal_field ||= custom_ticket_fields_from_cache.select(&field_type).map(&field_name)
  end

  def custom_ticket_fields_from_cache
    @custom_tf_from_cache ||= current_account.ticket_fields_from_cache
  end
end
