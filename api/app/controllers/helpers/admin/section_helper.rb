module Admin::SectionHelper
  include Admin::TicketFieldConstants

  private

    def section_inside_ticket_field?(tf)
      tf.picklist_values.section_picklist_join.exists?
    end

    def clear_on_empty_section
      unless section_inside_ticket_field?(@tf)
        @tf.field_options.delete 'section_present'
        @tf.save
      end
    end

    def construct_sections(ticket_field)
      section_response = []
      section_choice_map = choices_for_sections(ticket_field)
      tf_inside_section = ticket_field_for_sections(ticket_field)
      ticket_field.field_sections.each do |sec|
        next unless section_choice_map.key?(sec.id)
        res_hash = section_response_hash(sec, ticket_field)
        res_hash[:choice_ids] = section_choice_map[sec.id] || []
        res_hash[:ticket_field_ids] = tf_inside_section[sec.id] || []
        section_response << res_hash
      end
      section_response
    end

    def choices_for_sections(ticket_field)
      sec_picklist_map = ticket_field.section_picklist_mappings
      (sec_picklist_map || []).each_with_object({}) do |data, mapping|
        mapping[data.section_id] ||= []
        mapping[data.section_id] << data.picklist_id
      end
    end

    def ticket_field_for_sections(ticket_field)
      section_fields = ticket_field.section_ticket_fields
      (section_fields || []).each_with_object({}) do |data, mapping|
        mapping[data.section_id] ||= []
        mapping[data.section_id] << data.ticket_field_id
      end
    end

    def section_response_hash(section, ticket_field)
      {
        id: section.id,
        label: section.label,
        parent_ticket_field_id: ticket_field.id # TODO: section.ticket_field_id
      }
    end
end
