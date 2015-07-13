class ApiValidation
  include ActiveModel::Validations
  attr_accessor :error_options

  FORMATTED_TYPES = [ActiveSupport::TimeWithZone]

  # Set instance variables of validation class from request params or items. so that manual assignment is not needed.
  def initialize(request_params, item = nil)
    # Set instance variables of validation class from loaded item's attributes (incase of PUT/update request)
    if item
      item.attributes.each_pair do |field, value|
        instance_variable_set('@' + field, format_value(value))
      end
    end

    # Set instance variables of validation class from the request params.
    request_params.each_pair do |key, value|
      instance_variable_set('@' + key, value)
    end
  end

  # Set true for instance_variable_set if it is part of request params.
  # Say if request params has forum_type, forum_type_set attribute will be set to true.
  def check_params_set(request_params, item)
    if item
      item.attributes.each_pair do |field, value|
        instance_variable_set('@' + field + '_set', false)
      end
    end
    request_params.each_pair do |key, value|
      instance_variable_set('@' + key + '_set', true)
    end
  end

  def format_value(value)
    (FORMATTED_TYPES.include?(value.class) ? value.to_s : value)
  end
end
