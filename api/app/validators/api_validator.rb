class ApiValidator < ActiveModel::EachValidator
  ARRAY_MESSAGE_MAP = {
    data_type_mismatch: :array_data_type_mismatch,
    too_long: :array_too_long,
    invalid_format: :array_invalid_format
  }

  EMPTY_HASH = {}.freeze

  attr_reader :record, :attribute, :value, :values

  def validate(record)
    @record = record
    attributes.each do |attribute|
      value = record.read_attribute_for_validation(attribute)
      @attribute = attribute
      @value = value
      next if skip_validation?
      record.error_options[attribute] ||= {}
      @values = {}
      validate_each
    end
  end

  def validate_value(record, value)
    @record = record
    attributes.each do |attribute|
      @attribute = attribute
      @value = value
      next if skip_validation?
      record.error_options[attribute] ||= {}
      @values = {array: true}
      validate_each_value
    end
  end

  def required_attribute_not_defined?
    values[:req_attr_ndef] = options[:required] && !attribute_defined?
  end

  def attribute_defined?
    record.instance_variable_defined?("@#{attribute}")
  end

  def skip_validation?(validator_options = options)
    # if attribute is not set in request params and is not mandatory, all validations will be skipped irrespective of allow_nil, allow_blank options.
    errors_present? || !validator_options[:required] && (allow_unset?(validator_options) || allow_nil?(validator_options) || allow_blank?(validator_options))
  end

  def errors_present?
    record.errors[attribute].present?
  end

  def allow_nil?(validator_options)
    value.nil? && validator_options[:allow_nil]
  end

  def allow_blank?(validator_options)
    value.blank? && validator_options[:allow_blank]
  end

  def allow_unset?(_validator_options)
    !record.instance_variable_defined?("@#{attribute}")
  end

  def call_block(block)
    block.respond_to?(:call) ? block.call(record) : block
  end

  def validate_each
    record_error if invalid?
  end

  def validate_each_value
    record_array_field_error if invalid?
  end

  def record_array_field_error
    record.errors[attribute] << (options[:message] || ARRAY_MESSAGE_MAP[message] || message)
    record.error_options[attribute] = error_options.merge!(base_error_options)
  end

  def record_error
    record.errors[attribute] << (options[:message] || message)
    record.error_options[attribute] = error_options.merge!(base_error_options)
  end

  def present_or_false?
    value.present? || value.is_a?(FalseClass)
  end

  def allow_string?
    values[:allow_string] = (!options[:ignore_string].nil? && record.send(options[:ignore_string])) || options[:force_allow_string]
  end

  def base_error_options
    error_options = (options[:message_options] || EMPTY_HASH).dup
    code = error_code
    error_options.merge!(code: code) if code
    error_options
  end

  def error_options
    {}
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
end
