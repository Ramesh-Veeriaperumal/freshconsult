class CustomNumericalityValidator < ActiveModel::Validations::NumericalityValidator
  def validate_each(record, attribute, value)
    invalid_value = allow_nil(value) || !value.is_a?(Integer)
    invalid_value = (value <= 0) unless invalid_value
    if invalid_value
      message = options[:message] || 'data_type_mismatch'
      record.errors[attribute] << message
      (record.error_options ||= {}).merge!(attribute => { data_type: 'Positive Integer' })
    end
  end

  private

    def allow_nil(value) # if validation allows nil values and the value is nil, this will pass the validation.
      options[:allow_nil] == true && value.nil?
    end
end
