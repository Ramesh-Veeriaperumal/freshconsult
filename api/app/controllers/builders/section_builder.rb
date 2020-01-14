module SectionBuilder
  include Admin::TicketFieldConstants
  include Admin::TicketFields::CommonHelper

  private

    def modify_existing_section_field(section_field, data)
      return if delete_data(section_field, data)

      custom_data = data.dup
      custom_data[:position] ||= 1 # add into top if not there
      section_field.assign_attributes(section_field_params(custom_data))
    end

    def create_new_section_field(ticket_field, data)
      custom_data = data.dup
      custom_data.delete(:deleted)
      custom_data[:position] ||= 1 # add into top if not there
      ticket_field.section_fields.build(section_field_params(custom_data))
    end

    def update_ticket_field_options(ticket_field, section_fields, new_mapping)
      marked_for_deletion = section_fields.inject(0) { |sum, sf| sum + (sf.marked_for_destruction? ? 1 : 0) }
      if new_mapping > 0
        ticket_field.field_options['section'] = true
      elsif marked_for_deletion == section_fields.length
        ticket_field.field_options.delete('section')
      end
    end

    def associate_sections(ticket_field)
      section_fields = ticket_field.section_fields
      section_fields_by_section_id = section_fields.group_by(&:section_id)
      new_mapping = 0
      cname_params[:section_mappings].each do |section_mapping|
        sec_field = (section_fields_by_section_id[section_mapping[:section_id]] || []).first
        if sec_field.present?
          modify_existing_section_field(sec_field, section_mapping)
        else
          new_mapping += 1
          create_new_section_field(ticket_field, section_mapping)
        end
      end
      update_ticket_field_options(ticket_field, section_fields, new_mapping)
    end

    def section_field_params(section_mapping)
      section = (account_sections_group_by_id(@item)[section_mapping[:section_id]] || []).first
      section_mapping[:parent_ticket_field_id] = section.try(:[], :ticket_field_id)
      section_mapping
    end

    def account_sections_group_by_id(ticket_field)
      @account_sections_group_by_id ||= ticket_field.account_sections_from_cache.values.flatten.group_by(&:id)
    end
end
