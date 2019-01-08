module CustomAttributes
  CUSTOM_COLUMN_MAPPING = { custom_text: :custom_single_line_texts, custom_paragraph: :custom_paragraphs, custom_decimal: :custom_decimals, custom_number: :custom_numbers }.freeze  
  def get_custom_field_value(name)
    respond_to?(name) ? safe_send(name) : custom_field_value(name)
  end

  def fetch_custom_attributes
    denormalized_hash = Hash.new { |h, k| h[k] = [] }
    account.ticket_fields_from_cache.each do |tf|
      field_type = tf.field_type.to_sym
      if CUSTOM_COLUMN_MAPPING.key?(field_type)
        val = get_custom_field_value(tf.name)
        denormalized_hash[CUSTOM_COLUMN_MAPPING[field_type]] << val if val

      elsif [:custom_dropdown, :nested_field].include?(field_type)
        denormalized_hash[tf.column_name] = get_custom_field_value(tf.name)
      end
    end
    denormalized_hash
  end
end
