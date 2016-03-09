class DataTypeValidator < ApiValidator
  include ErrorOptions

  # Introduced this as the error message should show layman terms.
  DATA_TYPE_MAPPING = { Hash => 'key/value pair', ActionDispatch::Http::UploadedFile => 'valid file format', NilClass => NULL_TYPE, TrueClass => 'Boolean', FalseClass => 'Boolean' }

  private

    def invalid?
      !valid_type? || blank_when_required?
    end

    def message
      if valid_type? && blank_when_required?
        :blank
      else
        :data_type_mismatch
      end
    end

    def error_code
      :missing_field if required_attribute_not_defined?
    end

    def blank_when_required?
      return internal_values[:blank_when_required] if internal_values.key?(:blank_when_required)
      internal_values[:blank_when_required] = valid_type? && options[:rules] == String && options[:required] && !present_or_false?
    end

    def custom_error_options
      error_options = { expected_data_type: expected_data_type }
      error_options.merge!(given_data_type: infer_data_type(value), prepend_msg: :input_received) unless skip_input_info?
      error_options
    end

    def skip_input_info?
      required_attribute_not_defined? || blank_when_required? || array_value?
    end

    def expected_data_type
      DATA_TYPE_MAPPING[options[:rules]] || options[:rules]
    end

    # check if value class is same as type. case & when uses === operator which compares the type first.
    # Faster than is_a? check
    def valid_type?(type = options[:rules])
      return internal_values[:valid_type] if internal_values.key?(:valid_type)
      internal_values[:valid_type] = case value
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
