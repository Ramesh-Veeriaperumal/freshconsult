module Admin::ConditionHelper
  include Admin::ConditionValidationHelper
  include Admin::ConditionConstants

  def condition_validation(expected, actual)
    if expected[:field_type] == :nested_field
      validate_nested_field(expected, actual, :condition, :nested_fields)
    else
      validate_condition_value(expected, actual)
    end
  end

  def validate_condition_value(expected, actual)
    case_sensitive_validation(expected, actual) if actual.key?(:case_sensitive)
    associated_fields_validation(expected, actual) if actual.key?(:associated_fields)
    expecting_value, expected_data_type = validate_condition_operator(expected, actual)
    if expecting_value
      if actual.key?(:value)
        is_expected_data_type = valid_condition_data_type?(expected, actual[:value], expected_data_type)
        invalid_data_type("#{expected[:name]}[:value]", expected[:data_type], :invalid) unless is_expected_data_type
        validate_email(expected[:name], actual[:value]) if EMAIL_FIELD_TYPE.include?(expected[:field_type]) && is_expected_data_type &&
                                                           EMAIL_VALIDATOR_OPERATORS.include?(actual[:operator].to_sym)
        validate_date(expected[:name], actual[:value]) if expected[:field_type] == :date && is_expected_data_type
        validate_business_hours(expected[:name], actual) if BUSINESS_HOURS_FIELDS.include?(expected[:name])
        validate_association_type(expected[:name], actual) if expected[:name] == :association_type
      else
        missing_field_error(expected[:name], 'value')
      end
    else
      unexpected_parameter('value') if actual.key?(:value)
    end
  end

  def validate_condition_operator(expected, actual)
    operator_list = operator_list_by_field_type(expected)
    operator = operator_list.include?((actual[:operator].to_sym rescue actual[:operator]))
    if operator.present?
      expecting_value = !NO_VALUE_EXPECTING_OPERATOR.include?(actual[:operator].to_sym)
      text_field_value = SINGLE_VALUE_EXPECTING_OPERATOR.include?(actual[:operator].to_sym)
      text_field_value ||= (supervisor_rule? && SUPERVISOR_SINGLE_VALUE_OPERATOR.include?(actual[:operator].to_sym))
      expected_data_type = text_field_value ? 'single' : 'multiple'
    else
      missing_field_error(expected[:name], 'operator') unless actual.key?(:operator)
      not_included_error(:"#{expected[:name]}[operator]", operator_list) if actual.key?(:operator)
      expecting_value, expected_data_type = nil, nil
    end
    [expecting_value, expected_data_type]
  end

  def operator_list_by_field_type(expected)
    if supervisor_rule? && SUPERVISOR_FIELD_TYPE.key?(expected[:field_type])
      operators = FIELD_TYPE[SUPERVISOR_FIELD_TYPE[expected[:field_type]]]
    else
      operators = FIELD_TYPE[expected[:field_type]]
    end
    operators
  end

  def case_sensitive_validation(expected, actual)
    if expected[:field_type] == :text
      return missing_field_error(expected[:name], 'case_sensitive') unless actual.key?(:case_sensitive)
      case_sensitive = BOOLEAN.include?(actual[:case_sensitive])
      invalid_data_type(":case_sensitive", BOOLEAN.join(', '), actual[:case_sensitive]) unless case_sensitive
    else
      not_allowed_error(actual[:field_name])
    end
  end

  def associated_fields_validation(expected, actual)
    return unexpected_parameter('associated_fields') if (actual[:field_name] != 'association_type') ||
                                                        supervisor_rule? ||
                                                        dispatcher_rule? ||
                                                        PARENT_CHILD_ASSOCIATION_TYPES.include?(actual[:value])
    associated_fields = actual[:associated_fields]
    return missing_field_error(expected[:name], 'associated_fields[field_name]') unless associated_fields.key?(:field_name)
    not_included_error(:"#{expected[:name]}[associated_fields][field_name]", 
                       ASSOCIATED_FIELD_NAMES) unless ASSOCIATED_FIELD_NAMES.include?(associated_fields[:field_name])
    return missing_field_error(expected[:name], 'associated_fields[operator]') unless associated_fields.key?(:operator)
    not_included_error(:"#{expected[:name]}[associated_fields][operator]", 
                       ASSOCIATED_TICKET_OPERATORS) if associated_fields.key?(:operator) &&
                                                       !ASSOCIATED_TICKET_OPERATORS.include?(associated_fields[:operator])
    return missing_field_error(expected[:name], 'associated_fields[value]') unless associated_fields.key?(:value)
    invalid_data_type("#{expected[:name]}[associated_fields][value]", 
                      Integer, 
                      :invalid) if associated_fields.key?(:value) && !associated_fields[:value].is_a?(Integer)
  end

  def valid_condition_data_type?(expected, value, expected_data_type)
    data_type_class = expected[:data_type].to_s.constantize
    array_values_check = value.is_a?(Array) && value.all? {|x| x.is_a?(data_type_class) || none_value?(x, none_field?(expected))}
    is_expected_data_type = value.is_a?(expected_data_type == 'multiple' ? Array : data_type_class)
    is_expected_data_type &&= array_values_check if expected_data_type == 'multiple'
    expected[:allow_any_type] || is_expected_data_type ||
      none_value?(value, none_field?(expected)) ||
      any_none_value?(value, expected_data_type == 'single' && expected[:field_type] == :nested_field)
  end

  def none_field?(expected)
    none_or_any = CONDITION_NONE_FIELDS.include?(expected[:name])
    none_or_any || (CUSTOM_FIELD_NONE_OR_ANY.include?(expected[:field_type]) && expected[:custom_field])
  end
end
