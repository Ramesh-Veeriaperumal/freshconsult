class DataTypeValidator < ActiveModel::EachValidator
  # Introduced this as the error message should show layman terms.
  # Should have error_options attribute for a class to use this validator
  DATA_TYPE_MAPPING = { Hash => 'key/value pair', ActionDispatch::Http::UploadedFile => 'format' }

  def validate_each(record, attribute, values)
    unless valid_type?(options[:rules], values)
      record.errors[attribute] = options[:message] || 'data_type_mismatch'
      data_type = DATA_TYPE_MAPPING.key?(options[:rules]) ? DATA_TYPE_MAPPING[options[:rules]] : options[:rules]
      (record.error_options ||= {}).merge!(attribute => { data_type: data_type })
    end
  end

  private
  
    def valid_type?(type, value)
      type == 'Boolean' ? [true, false].include?(value) : (value.is_a? type)
    end
end
