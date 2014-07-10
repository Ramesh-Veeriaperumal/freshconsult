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
        :field_options          => field.field_options

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
          field.choices
      end
    end
end
