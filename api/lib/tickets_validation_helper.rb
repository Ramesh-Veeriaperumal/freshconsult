class TicketsValidationHelper
  class << self
    def ticket_type_values
      Account.current ? Account.current.ticket_types_from_cache.map(&:value) : []
    end

    def name_mapping(ticket_fields)
      ticket_fields.reject(&:default).each_with_object({}) { |ticket_field, hash| hash[ticket_field.name] = TicketDecorator.display_name(ticket_field.name) }
    end

    def custom_dropdown_fields(delegator)
      delegator.ticket_fields.select { |c| (['custom_dropdown', 'nested_field'].include?(c.field_type)) }
    end

    def custom_non_dropdown_fields(delegator)
      delegator.ticket_fields.select { |c| (!c.default && ['custom_dropdown', 'nested_field'].exclude?(c.field_type)) }
    end

    def custom_dropdown_field_choices
      Account.current.custom_dropdown_fields_from_cache.collect do |x|
        [x.name, x.choices.flatten.uniq]
      end.to_h
    end

    def section_field_parent_field_mapping
      section_fields = Account.current.section_fields_with_field_values_mapping_cache

      # Ex:  {11=>{"ticket_type"=>["Incident", "Lead", "Question"]}, 12=>{"ticket_type"=>["Question"]}, 31=>{"ticket_type"=>["Question"]}}
      parent_field_value_mapping(section_fields).each_with_object(Hash.new) do |(k, v), inverse| 
        v.each do |e| 
          inverse[e] = (inverse[e] || {}).merge(k){ |k, o, n| o + n }
        end
      end
    end

    def parent_field_value_mapping(section_fields)
      #Ex: [[{"ticket_type"=>["Question", "Feature Request"]}, [11, 12, 13]], [{"ticket_type"=>["Problem"]}, [11]]]
      section_fields.group_by{|x| {x.parent_ticket_field.name =>  x.section.section_picklist_mappings.map{|x| x.picklist_value.value}}}.map{|x, y|[x, y.map(&:ticket_field_id)]}
    end

    def custom_nested_field_choices
      Account.current.nested_fields_from_cache.collect { |x| [x.name, x.formatted_nested_choices] }.to_h
    end

    # compute the size of attachments associated with the record.
    def attachment_size(item)
      item.try(:attachments).try(:sum, &:content_file_size).to_i
    end

    def custom_checkbox_names(ticket_fields)
      ticket_fields.select { |x| x.field_type.to_sym == :custom_checkbox }.map(&:name)
    end
  end
end
