position = 1
section_field_position = @items.length - @dependent_field_ticket_field_id_mapping.length * 2 - @section_ticket_field_id_mapping.length
section_field_position -= 1 if current_account.products_from_cache.length == 0
json.array! @items do |item|
  item_hash = item.to_hash(true)
  if item_hash.length != 0
    item_hash[:section_mappings] =  @section_ticket_field_id_mapping[item_hash[:id]] if @section_ticket_field_id_mapping[item_hash[:id]].present?
    item_hash[:dependent_fields] =  @dependent_field_ticket_field_id_mapping[item_hash[:id]] if @dependent_field_ticket_field_id_mapping[item_hash[:id]].present?
    if item_hash[:section_mappings].present?
      section_field_position += 1
      item_hash[:position] = section_field_position
      json.merge! item_hash
    else
      item_hash[:position] = position
      json.merge! item_hash
      position += 1
    end
  end
end