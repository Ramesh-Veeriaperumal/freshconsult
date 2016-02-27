class ApiValidator < ActiveModel::EachValidator
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
      @values = {}
      validate_each
    end
  end

  def required_attribute_not_defined?
    options[:required] && !attribute_defined?
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

  def record_error
    record.errors[attribute] << (options[:message] || message)
    record_error_options = error_options
    record.error_options[attribute].merge!(record_error_options) if record_error_options
  end

  def present_or_false?
    value.present? || value.is_a?(FalseClass)
  end

  def allow_string?
    values[:allow_string] = (!options[:ignore_string].nil? && record.send(options[:ignore_string])) || options[:force_allow_string]
  end

  def error_options
    # set options here that help in determining code of the error message and params passed to error_messages.yml.
  end

  def message
    # the error message that should be added if the record is invalid.
  end

  def invalid?
    # condition that determines the validity of the record.
  end
end
