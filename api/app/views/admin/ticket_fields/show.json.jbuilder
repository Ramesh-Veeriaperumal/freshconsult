json.merge! @decorated_item.to_hash
json.merge! section_mappings: @section_ticket_field_id_mapping[@decorated_item.id] if @section_ticket_field_id_mapping[@decorated_item.id].present?
json.merge! dependent_fields: @dependent_field_ticket_field_id_mapping[@decorated_item.id] if @dependent_field_ticket_field_id_mapping[@decorated_item.id].present?
