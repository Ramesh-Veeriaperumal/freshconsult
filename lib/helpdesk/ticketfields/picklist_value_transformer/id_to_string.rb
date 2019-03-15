class Helpdesk::Ticketfields::PicklistValueTransformer::IdToString < Helpdesk::Ticketfields::PicklistValueTransformer::Base
  def transform(picklist_id, flexifield_name)
    field = ticket_field_by_flexifield_name_hash[flexifield_name]
    return if field.blank?

    picklist_value_mapping = picklist_values_by_id(field)
    picklist_value_mapping && picklist_value_mapping[picklist_id]
  end

  private

    def picklist_values_by_id(field)
      mapping = values_by_id_from_cache[field.picklist_values_by_id_key]
      mapping.presence || field.picklist_values_by_id_from_cache
    end
end
