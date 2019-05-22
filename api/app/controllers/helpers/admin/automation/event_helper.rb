module Admin::Automation::EventHelper
  include Admin::AutomationConstants
  include Admin::AutomationValidationHelper

  def event_validation(expected, actual)
    case expected[:field_type]
      when :nested_field
        validate_nested_field(expected, actual, :event, :from_nested_field)
        validate_nested_field(expected, actual, :event, :to_nested_field)
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

  def valid_event_data_type?(expected, value)
    data_type_class = expected[:data_type].to_s.constantize
    is_expected_data_type = value.is_a?(data_type_class)
    expected[:allow_any_type] || is_expected_data_type || none_value?(value, EVENT_NONE_FIELDS.include?(expected[:name])) ||
        any_value?(value, EVENT_ANY_FIELDS.include?(expected[:name]))
  end

end