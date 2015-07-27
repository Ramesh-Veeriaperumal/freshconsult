module TicketFieldsHelper

  def ticket_field_hash(ticket_fields, account)
    ticket_fields.map do |field|
      { :field_type             => field.field_type,
        :id                     => field.id,
        :name                   => field.name,
        :dom_type               => field.dom_type,
        :label                  => ( field.is_default_field? ) ? I18n.t("ticket_fields.fields.#{field.name}") : field.label,
        :label_in_portal        => field.label_in_portal,
        :description            => field.description,
        :field_type             => field.field_type,
        :position               => field.position,
        :active                 => field.active,
        :required               => field.required,
        :required_for_closure   => field.required_for_closure,
        :visible_in_portal      => field.visible_in_portal,
        :editable_in_portal     => field.editable_in_portal,
        :required_in_portal     => field.required_in_portal,
        :choices                => get_choices(field, account),
        :levels                 => field.levels,
        :level_three_present    => field.level_three_present,
        :field_options          => field.field_options || { :section   => false},
        :has_section            => field.has_section?

      }
    end
  end

  def section_data_hash(sections, account)
    sections.map do |section|
      section_fields = generate_section_fields(section)
      parent_ticket_field_id = section_fields.present? ? section_fields[0][:parent_ticket_field_id] : 
                                                         section.parent_ticket_field_id
      {
        :id                     => section.id,
        :label                  => section.label,
        :section_fields         => section_fields,
        :parent_ticket_field_id => parent_ticket_field_id,
        :picklist_ids           => generate_section_picklist_mappings(section)
      }
    end
  end

  private

    def get_choices(field, account)
      case field.field_type
        when "nested_field" then
          field.nested_choices
        when "default_status" then
          Helpdesk::TicketStatus.statuses_list(account)
        else
          field.choices(nil, true)
      end
    end

    def generate_section_fields(section)
      section.section_fields.map do |field|
        {
          :id => field.id,
          :position => field.position,
          :ticket_field_id => field.ticket_field_id,
          :parent_ticket_field_id => field.parent_ticket_field_id
        }
      end
    end

    def generate_section_picklist_mappings(section)
      section.section_picklist_mappings.map do |mapping|
        {
          :picklist_value_id => mapping.picklist_value_id
        }
      end
    end
end
