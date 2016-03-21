module ErrorOptions
  UNIDENTIFIED_TYPE = 'Unidentified Type'
  NULL_TYPE = 'Null Type'

  def custom_error_options
    error_options = { expected_data_type: expected_data_type }
    error_options.merge!(prepend_msg: :input_received, given_data_type: infer_data_type(value, internal_values)) unless skip_input_info?
    error_options
  end

  def string_input_and_allow_string?
    allow_string? && expected_simple_type? && given_string_type?
  end

  def expected_simple_type?
    expected_data_type != Array && expected_data_type != Hash
  end

  def given_string_type?
    infer_data_type(value, internal_values) == String
  end

  def infer_data_type(value, internal_values = {})
    return internal_values[:given_type] if internal_values.key?(:given_type)
    internal_values[:given_type] = simple_types(value) || DataTypeValidator::DATA_TYPE_MAPPING[formatted_types(value)] || UNIDENTIFIED_TYPE
  end

  def simple_types(value)
    detect_data_type(Integer, Float, Array, String, value)
  end

  def formatted_types(value)
    detect_data_type(Hash, NilClass, TrueClass, FalseClass, ActionDispatch::Http::UploadedFile, value)
  end

  def detect_data_type(*types, value)
    types.detect { |type| value.is_a?(type) }
  end
end
