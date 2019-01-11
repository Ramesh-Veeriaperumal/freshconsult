module Sync::Transformer::Util
  def apply_custom_field_name_mapping(name_field, mapping_info)
    if name_field.present? && mapping_info[name_field.to_s].present?
      mapping_info[name_field.to_s]
    else
      name_field
    end
  end

  def apply_id_mapping(value, mapping_info = {}, model = '', reverse = false)
    Sync::Logger.log("Inside apply_id_mapping, value: #{value.inspect} mapping_info: #{mapping_info.inspect}, model: #{model}, reverse: #{reverse}, resync: #{@resync}")
    if value.present? && (value.is_a?(Array) || !value.to_i.zero?)
      if value.is_a? Array
        value.map { |val| apply_id_mapping(val, mapping_info, model, reverse) }
      elsif clone_or_resync? && mapping_info.key?(value.to_i)
        mapping_value(mapping_info, value)
      elsif !skip_transformation?(value, model) && value.to_i > 0
        calc_id(value, reverse)
      else
        value
      end
    else
      value
    end
  end

  def mapping_value(mapping_info, value)
    new_value = mapping_info[value.to_i]
    new_value ? new_value.is_a?(String) ? new_value.to_s : new_value.to_i : new_value
  end

  def get_mapping_data(model, mapping_table, mapped_column = :id)
    return {} if mapping_table[model.to_s].blank?
    mapping_table[model.to_s][mapped_column] || {}
  end

  private

    def clone_or_resync?
      @clone || @resync
    end
end
