class DataTypeValidator < ActiveModel::EachValidator
  # Introduced this as the error message should show layman terms.
  # Should have error_options attribute for a class to use this validator
  DATA_TYPE_MAPPING = { Hash => 'key/value pair', ActionDispatch::Http::UploadedFile => 'valid format' }

  def validate_each(record, attribute, values)
    return if record.errors[attribute].present?

    message = options[:message]
    message ||= required_attribute_not_defined?(record, attribute, values) ? :required_and_data_type_mismatch : :data_type_mismatch

    if valid_type?(options[:rules], values, record, attribute) 
      record.errors[attribute] = :blank if options[:required] && !present_or_false?(values)
    else
      record.errors[attribute] << message
      data_type = DATA_TYPE_MAPPING.key?(options[:rules]) ? DATA_TYPE_MAPPING[options[:rules]] : options[:rules]
      (record.error_options ||= {}).merge!(attribute => { data_type: data_type })
    end
  end

  private

    # check if value class is same as type. case & when uses === operator which compares the type first.
    # Faster than is_a? check
    def valid_type?(type, value, record, attribute)
      case value
      when NilClass
        allow_unset?(type) && !record.instance_variable_defined?("@#{attribute}")
      when type
        true
      when TrueClass, FalseClass
        type == 'Boolean'
      when 'true', 'false'
        type == 'Boolean' && allow_string?(record)
      else
        false
      end
    end

    def required_attribute_not_defined?(record, attribute, _value)
      options[:required] && !record.instance_variable_defined?("@#{attribute}")
    end

    def allow_string?(record)
      !options[:ignore_string].nil? && record.send(options[:ignore_string])
    end

    def allow_unset?(type)
      !options[:required] && ([Hash, Array, 'Boolean'].include?(type) || options[:allow_unset])
    end

    def present_or_false?(value)
      value.present? || value.is_a?(FalseClass)
    end
end
