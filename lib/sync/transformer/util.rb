module Sync::Transformer::Util
  def apply_custom_field_name_mapping(name_field, mapping_info)
    if name_field.present? && mapping_info[name_field.to_s].present?
      mapping_info[name_field.to_s]
    else
      name_field
    end
  end

  def apply_id_mapping(value, mapping_info)
    if value.is_a? Array
      value.map { |val| val.present? && mapping_info[val.to_i].present? ? mapping_value(mapping_info, val) : val }
    else
      value.present? && mapping_info[value.to_i].present? ? mapping_value(mapping_info, value) : value
    end
  end

  def mapping_value(mapping_info, value)
    value.is_a?(String) ? mapping_info[value.to_i].to_s : mapping_info[value.to_i].to_i
  end

  def get_mapping_data(model, mapping_table, mapped_column = :id)
    return {} if mapping_table[model.to_s].blank?
    mapping_table[model.to_s][mapped_column] || {}
  end
end
