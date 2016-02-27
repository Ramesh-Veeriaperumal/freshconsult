class DataTypeValidator < ApiValidator
  # Introduced this as the error message should show layman terms.
  # Should have error_options attribute for a class to use this validator
  DATA_TYPE_MAPPING = { Hash => 'key/value pair', ActionDispatch::Http::UploadedFile => 'valid format' }

  private

    def invalid?
      blank_when_required? || !valid_type?
    end

    def message
      valid_type? && values[:blank_when_required] ? :blank : :data_type_mismatch
    end

    def blank_when_required?
      values[:blank_when_required] = options[:rules] == String && options[:required] && !present_or_false?
    end

    def error_options
      data_type = DATA_TYPE_MAPPING[options[:rules]] || options[:rules]
      error_options = { data_type: data_type }
      error_options.merge!(code: :missing_field) if required_attribute_not_defined?
      error_options
    end

    # check if value class is same as type. case & when uses === operator which compares the type first.
    # Faster than is_a? check
    def valid_type?(type = options[:rules])
      case value
      when type
        true
      when TrueClass, FalseClass
        type == 'Boolean'
      when 'true', 'false'
        type == 'Boolean' && allow_string?
      else
        false
      end
    end
end
