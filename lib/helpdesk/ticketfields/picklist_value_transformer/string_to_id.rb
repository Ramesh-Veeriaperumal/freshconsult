class Helpdesk::Ticketfields::PicklistValueTransformer::StringToId < Helpdesk::Ticketfields::PicklistValueTransformer::Base
  def transform(picklist_value, flexifield_name)
    picklist_value = picklist_value.downcase
    field = ticket_field_by_flexifield_name_hash[flexifield_name]
    picklist_value_mapping = picklist_ids_by_value(field)
    return if picklist_value_mapping.nil?

    if field.child_nested_field?
      base_val = picklist_value_mapping[picklist_value]
      return if base_val.nil?

      if @ticket
        if field.level == 3
          field, base_val = parent_field_value(field, base_val)
          return if base_val.nil?
        end
        _, base_val = parent_field_value(field, base_val)
      end
      base_val
    else
      picklist_value_mapping[picklist_value]
    end
  end

   private

    def picklist_ids_by_value(field)
      field.picklist_ids_by_value_from_cache
    end

    def parent_field_value(ticket_field, base_val)
      parent_field = ticket_field.parent_field
      parent_value = @ticket.safe_send(parent_field.name).downcase
      [parent_field, base_val && base_val[parent_value]]
    end
end
