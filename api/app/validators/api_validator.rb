class ApiValidator < ActiveModel::EachValidator
  ARRAY_MESSAGE_MAP = {
    datatype_mismatch: :array_datatype_mismatch,
    too_long: :array_too_long,
    invalid_format: :array_invalid_format
  }.freeze

  attr_reader :record, :attribute, :value, :internal_values

  def validate(record)
    @record = record
    attributes.each do |attribute|
      @internal_values = {}
      @value = options[attribute].try(:value) || record.read_attribute_for_validation(attribute)
      @attribute = attribute
      next if skip_validation?
      record.error_options[attribute] ||= {}
      validate_each
    end
  end

  def validate_value(record, value)
    @record = record
    attributes.each do |attribute|
      @internal_values = { array: true }
      @attribute = attribute
      @value = value
      next if skip_validation?
      record.error_options[attribute] ||= {}
      validate_each_value
    end
  end

  def validate_each
    record_error if invalid?
  end

  def validate_each_value
    record_array_field_error if invalid?
  end

  private

    def required_attribute_not_defined?
      return internal_values[:req_attr_ndef] if internal_values.key?(:req_attr_ndef)
      internal_values[:req_attr_ndef] = options[:required] && !attribute_defined?
    end

    def attribute_defined?
      @value != ApiConstants::VALUE_NOT_DEFINED &&
        record.instance_variable_defined?("@#{attribute}")
    end

    def skip_validation?(validator_options = options)
      # if attribute is not set in request params and is not mandatory, all validations will be skipped irrespective of allow_nil, allow_blank options.
      errors_present? || !validator_options[:required] && (allow_unset? || allow_nil?(validator_options) || allow_blank?(validator_options))
    end

    def errors_present?
      record.errors[attribute].present?
    end

    def allow_nil?(validator_options)
      validator_options[:allow_nil] && value.nil?
    end

    def allow_blank?(validator_options)
      validator_options[:allow_blank] && value.blank?
    end

    def allow_unset?
      !attribute_defined?
    end

    def call_block(block)
      block.respond_to?(:call) ? block.call(record) : block
    end

    def record_array_field_error
      record.errors[attribute] << (options[:message] || child_message || message)
      record.error_options[attribute] = custom_error_options.merge!(base_error_options)
    end

    def record_error
      record.errors[attribute] << (options[:message] || message)
      record.error_options[attribute] = custom_error_options.merge!(base_error_options)
    end

    def present_or_false?
      value.present? || value.is_a?(FalseClass)
    end

    def allow_string?
      return internal_values[:allow_string] if internal_values.key?(:allow_string)
      internal_values[:allow_string] = (!options[:ignore_string].nil? && record.send(options[:ignore_string])) || options[:force_allow_string]
    end

    def base_error_options
      error_options = (options[:message_options] ? options[:message_options].dup : {})
      code = options[:code] || error_code
      error_options[:code] = code if code
      nested_field = child_field_name
      error_options[:nested_field] = nested_field if nested_field
      error_options
    end

    def nested_field_name
      options[:nested_field]
    end

    def custom_error_options
      {}
    end

    def child_field_name
      options[:nested_field]
    end

    def child_message
      ARRAY_MESSAGE_MAP[message] unless child_field_name
    end

    def error_code
      # set code here to override the deault code assignment that would happen using ErrorConstants::API_ERROR_CODES_BY_VALUE
    end

    def message
      # the error message that should be added if the record is invalid.
    end

    def invalid?
      # condition that determines the validity of the record.
    end

    def array_value?
      internal_values[:array]
    end
end
