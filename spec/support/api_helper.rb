module APIHelper

  SKIPPED_KEYS = [:created_at, :updated_at, :id]

  def xml skipped_keys = SKIPPED_KEYS # Converts xml string to hash
    @xml ||= deep_skip_keys(Hash.from_trusted_xml(response.body).deep_symbolize_keys, skipped_keys)
  end

  def json skipped_keys = SKIPPED_KEYS # Converts json string to hash
    @json ||= deep_skip_keys(JSON.parse(response.body).deep_symbolize_keys, skipped_keys)
  end

  def deep_skip_keys array_or_hash, skipped_keys
    if array_or_hash.is_a? Hash
      array_or_hash.each do |key, value|
        array_or_hash.delete(key) if skipped_keys.include? key
        array_or_hash[key] = deep_skip_keys(value, skipped_keys) if(value.is_a?(Hash) || value.is_a?(Array))
      end
    end
    if array_or_hash.is_a? Array
      array_or_hash.each do |element|
        element = deep_skip_keys(element, skipped_keys) if(element.is_a?(Hash) || element.is_a?(Array))
      end
    end
    array_or_hash
  end

  def clear_xml
    @xml = nil
  end

  def clear_json
    @json = nil
  end

  def clear_xml_and_json
    clear_xml
    clear_json
  end

end