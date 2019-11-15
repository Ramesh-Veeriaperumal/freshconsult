module Admin::ConditionErrorHelper
  def errors_for_invalid_attributes
    @invalid_attributes.each do |invalid_param|
      unexpected_parameter(invalid_param)
    end
    false
  end

  def construct_key(name)
    field_position.present? ? :"#{type_name}[:#{name}][#{field_position}]" : :"#{type_name}[:#{name}]"
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

  def invalid_url(name, url)
    errors[construct_key(name)] << :invalid_url
    error_message = {}
    error_message[construct_key(name)] = {value: url}
    error_options.merge!(error_message)
  end

  def not_allowed_error(name, message = :case_sensitive_not_allowed)
    errors[construct_key(name)] << message
    error_message = {}
    error_message[construct_key(name)] = {name: name}
    error_options.merge!(error_message)
  end

  def invalid_position_error(name, max_position)
    errors[construct_key(name)] << :invalid_position
    error_message = {}
    error_message[construct_key(name)] = { max_position: max_position }
    error_options.merge!(error_message)
  end

  def merge_to_parent_errors(validation)
    validation.errors.to_h.each_pair do |key, value|
      errors[key] << value
    end
  end

  def invalid_condition_set_count(count)
    errors[:condition_sets] << :invalid_condition_set_count
    error_message = {}
    error_message[:condition_sets] = { count: count }
    error_options.merge!(error_message)
  end
end