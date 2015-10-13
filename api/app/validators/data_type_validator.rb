class DataTypeValidator < ActiveModel::EachValidator
  # Introduced this as the error message should show layman terms.
  # Should have error_options attribute for a class to use this validator
  DATA_TYPE_MAPPING = { Hash => 'key/value pair', ActionDispatch::Http::UploadedFile => 'valid format' }

  def validate_each(record, attribute, values)
    return if record.errors[attribute].present?
    
    message = options[:message]
    message ||= required_attribute_not_defined?(record, attribute, values) ? 'required_and_data_type_mismatch' : 'data_type_mismatch'

    unless valid_type?(options[:rules], values, record)
      record.errors[attribute] = message
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

    def required_attribute_not_defined?(record, attribute, value)
      options[:required] && !record.instance_variable_defined?("@#{attribute}".to_sym)
    end

    def allow_string?(record)
      !options[:ignore_string].nil? && record.send(options[:ignore_string])
    end
end
