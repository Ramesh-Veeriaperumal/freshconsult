class ApiValidation
  include ActiveModel::Validations

  FORMATTED_TYPES = [ActiveSupport::TimeWithZone]

  # Set instance variables of validation class from request params or items. so that manual assignment is not needed.
  def initialize(request_params, item)
    # Set instance variables of validation class from loaded item's attributes (incase of PUT/update request)
    if item
      item.attributes.each_pair do |field, value|
        instance_variable_set('@' + field, format_value(value)) if self.class.instance_methods.include?(field.to_sym)
      end
    end
    # Set instance variables of validation class from the request params.
    request_params.each_pair do |key, value|
      instance_variable_set('@' + key, value)
    end
  end

  def format_value(value)
    (FORMATTED_TYPES.include?(value.class) ? value.to_s : value)
  end
end
