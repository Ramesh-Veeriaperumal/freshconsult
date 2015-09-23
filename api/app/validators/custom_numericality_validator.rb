class CustomNumericalityValidator < ActiveModel::Validations::NumericalityValidator
  def validate_each(record, attribute, value)
    valid_value = value.is_a?(Integer)
    valid_value = (value > 0) if valid_value && options[:allow_negative] != true
    unless valid_value
      message = options[:message] || 'data_type_mismatch'
      record.errors[attribute] << message
      (record.error_options ||= {}).merge!(attribute => { data_type: data_type(options[:allow_negative]) })
    end
  end

  private

    def data_type(allow_negative)
      allow_negative ? 'Integer' : 'Positive Integer'
    end

end
