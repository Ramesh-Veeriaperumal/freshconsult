class DataTypeValidator < ActiveModel::EachValidator
  # Introduced this as the error message should show layman terms.
  # Should have error_options attribute for a class to use this validator
  DATA_TYPE_MAPPING = { Hash => 'key/value pair', ActionDispatch::Http::UploadedFile => 'format' }

  def validate_each(record, attribute, values)
    unless allow_nil(values) || valid_type?(options[:rules], values)
      record.errors[attribute] << 'data_type_mismatch'
      data_type = DATA_TYPE_MAPPING.key?(options[:rules]) ? DATA_TYPE_MAPPING[options[:rules]] : options[:rules]
      (record.error_options ||= {}).merge!(attribute => { data_type: data_type })
    end
  end

  private

    def allow_nil(value) # if validation allows nil values and the value is nil, this will pass the validation.
      options[:allow_nil] == true && value.nil?
    end

    def valid_type?(type, value)
      value.is_a? type
    end
end
