class ApiValidation
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks
  attr_accessor :error_options

  before_validation :trim_attributes
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

  def trim_attributes
    attributes_to_be_stripped.each do |x|
      attribute = send(x)
      next if attribute.nil?
      if attribute.respond_to?(:strip!)
        attribute.strip!
      elsif attribute.is_a?(Array)
        attribute.each { |element| strip_attribute(element) }
      elsif attribute.is_a?(Hash)
        attribute.each { |key, value| strip_attribute(value) }
      end
    end
  end

  def strip_attribute(attribute)
    attribute.strip! if attribute.respond_to?(:strip!)
  end

  def attributes_to_be_stripped
  end
end
