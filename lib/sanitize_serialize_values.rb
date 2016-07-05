module SanitizeSerializeValues

  def sanitize_hash_values(inputs_hash)
    inputs_hash.each do |key, value|
      inputs_hash[key] = sanitize_value(value)
    end
  end

  def sanitize_array_values(inputs_array)
    inputs_array.each_with_index do |value, index|
      inputs_array[index] = sanitize_value(value)
    end
  end

  def sanitize_value(value)
    value.is_a?(Array) ? sanitize_array_values(value) : ( value.is_a?(Hash) ?
        sanitize_hash_values(value) : RailsFullSanitizer.sanitize(value) )
  end
end