class DataTypeValidator < ActiveModel::EachValidator
  # Introduced this as the error message should show layman terms.
  # Should have error_options attribute for a class to use this validator
  DATA_TYPE_MAPPING = { Hash => 'key/value pair', ActionDispatch::Http::UploadedFile => 'format' }

  def validate_each(record, attribute, values)
    unless valid_type?(options[:rules], values, record)
      record.errors[attribute] = options[:message] || 'data_type_mismatch'
      data_type = DATA_TYPE_MAPPING.key?(options[:rules]) ? DATA_TYPE_MAPPING[options[:rules]] : options[:rules]
      (record.error_options ||= {}).merge!(attribute => { data_type: data_type })
    end
  end

  private

    # check if value class is same as type. case & when uses === operator which compares the type first.
    # Faster than is_a? check
    def valid_type?(type, value, record)
      case value
      when type
        true
      when TrueClass
        type == 'Boolean'
      when FalseClass
        type == 'Boolean'
      when 'true'
        type == 'Boolean' && allow_string?(record)
      when 'false'
        type == 'Boolean' && allow_string?(record)
      else
        false
      end
    end

    def allow_string?(record)
      !options[:ignore_string].nil? && record.send(options[:ignore_string])
    end
end
