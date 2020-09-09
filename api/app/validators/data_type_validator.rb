class DataTypeValidator < ApiValidator
  include ErrorOptions

  # Introduced this as the error message should show layman terms.
  DATA_TYPE_MAPPING = { Hash => 'key/value pair', ActionDispatch::Http::UploadedFile => 'valid file format', NilClass => NULL_TYPE, TrueClass => 'Boolean', FalseClass => 'Boolean' }.freeze

  private

    def invalid?
      !valid_type? || blank_when_required? || empty_object?
    end

    def message
      if valid_type? && (blank_when_required? || empty_object?)
        :blank
      else
        :datatype_mismatch
      end
    end

    def error_code
      :missing_field if required_attribute_not_defined?
    end

    def blank_when_required?
      return internal_values[:blank_when_required] if internal_values.key?(:blank_when_required)
      internal_values[:blank_when_required] = valid_type? && options[:rules] == String && options[:required] && !present_or_false?
    end

    def empty_object?
      internal_values[:empty_object] = valid_type? && options[:not_empty] && value.blank?
    end

    def expected_data_type
      return internal_values[:expected_data_type] if internal_values.key?(:expected_data_type)
      internal_values[:expected_data_type] = DATA_TYPE_MAPPING[options[:rules]] || options[:rules]
    end

    def skip_input_info?
      required_attribute_not_defined? || blank_when_required? || array_value? || string_input_and_allow_string?
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
