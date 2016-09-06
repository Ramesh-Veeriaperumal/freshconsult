class ApiValidation
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks
  attr_accessor :error_options, :allow_string_param, :ids

  before_validation :trim_attributes
  validates :ids, required: true, data_type: { rules: Array, allow_nil: false }, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false, ignore_string: :allow_string_param, greater_than: 0 } }, if: :is_bulk_action?

  FORMATTED_TYPES = [ActiveSupport::TimeWithZone]
  CHECK_PARAMS_SET_FIELDS = []

  # Set instance variables of validation class from request params or items. so that manual assignment is not needed.
  def initialize(request_params, item = nil, allow_string_param = false)
    # Set instance variables of validation class from loaded item's attributes (incase of PUT/update request)
    if item
      item.attributes.keys.each do |field, value|
        send("#{field}=", format_value(item.send(field))) if respond_to?("#{field}=")
      end
    end

    # Set instance variables of validation class from the request params.
    set_instance_variables(request_params)

    # Allow string param based on action & content_type
    @allow_string_param = allow_string_param
    @error_options = {}
    check_params_set(request_params.slice(*self.class::CHECK_PARAMS_SET_FIELDS)) if self.class::CHECK_PARAMS_SET_FIELDS.any?
  end

  # Set true for instance_variable_set if it is part of request params.
  # Say if request params has forum_type, forum_type_set attribute will be set to true.
  def check_params_set(request_params)
    request_params.each_pair do |key, value|
      instance_variable_set("@#{key}_set", true)
      check_params_set(value) if value.is_a?(Hash)
    end
  end

  def fill_custom_fields(request_params, custom_fields)
    if !request_params.key?(:custom_fields)
      @custom_fields = custom_fields.reject { |k, v| v.nil? }
    elsif request_params[:custom_fields].is_a?(Hash)
      @custom_fields = custom_fields.reject { |k, v| v.nil? }.merge(request_params[:custom_fields])
    end
  end

  def format_value(value)
    (FORMATTED_TYPES.include?(value.class) ? value.iso8601 : value)
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
    []
  end

  def set_instance_variables(request_params)
    request_params.each_pair do |key, value|
      if respond_to?("#{key}=")
        send("#{key}=", value)
      else
        instance_variable_set("@#{key}", value)
      end
      set_instance_variables(value) if value.is_a?(Hash)
    end
  end

  def is_bulk_action?
    ApiConstants::BULK_ACTION_METHODS.include?(validation_context)
  end

end
