class CustomNumericalityValidator < ActiveModel::Validations::NumericalityValidator
  def validate_each(record, attribute, value)
    return if record.errors[attribute].present?

    message = options[:message]
    message ||= required_attribute_not_defined?(record, attribute, value) ? :required_and_data_type_mismatch : :data_type_mismatch

    # if ignore_string is present and true, proceed with numericality validator.
    # else fall back to custom numericality which will not allow numbers in string representation say "1".
    if !options[:ignore_string].nil? && record.send(options[:ignore_string])
      super(record, attribute, value)
    else
      validate_numeric(record, attribute, value, message)
    end

    if record.errors[attribute].present?
      record.errors[attribute] = message
      (record.error_options ||= {}).merge!(attribute => { data_type: data_type(options[:allow_negative]) })
    end
  end

  private

    def validate_numeric(record, attribute, value, message)
      valid_value = value.is_a?(Integer) # true if integer.

      # true if value is +ve when allow_negative is false or nil
      valid_value = (value > 0) if valid_value && options[:allow_negative] != true
      record.errors[attribute] << message unless valid_value
    end

    def data_type(allow_negative)
      allow_negative ? 'Integer' : 'Positive Integer'
    end

    def required_attribute_not_defined?(record, attribute, _value)
      options[:required] && !record.instance_variable_defined?("@#{attribute}".to_sym)
    end
end
