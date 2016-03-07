module ErrorOptions
  UNIDENTIFIED_TYPE = 'Unidentified Type'
  NULL_TYPE = 'Null Type'

  def infer_data_type(value)
    simple_types(value) || DataTypeValidator::DATA_TYPE_MAPPING[formatted_types(value)] || UNIDENTIFIED_TYPE
  end

  def simple_types(value)
    detect_data_type(Integer, Float, Array, String, value)
  end

  def formatted_types(value)
    detect_data_type(Hash, NilClass, TrueClass, FalseClass, ActionDispatch::Http::UploadedFile, value)
  end

  def detect_data_type(*types, value)
    types.detect { |type| type === value }
  end
end
