class TicketFieldsController < CustomFieldsController

  def index
    @ticket_fields = current_portal.ticket_fields

    respond_to do |format|
      format.html {
        @ticket_field_json = @ticket_fields.map do |field|
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
            :choices                => get_choices(field),
            :levels                 => field.levels,
            :level_three_present    => field.level_three_present,
            :field_options          => field.field_options

          }

    end
      }
      format.xml  { render :xml => @ticket_fields.to_xml }
      format.json  { render :json => Hash.from_xml(@ticket_fields.to_xml) }
    end
  end

  private
    def edit_nested_field(ticket_field,nested_field)
      nested_field.delete(:type)
      nested_field.delete(:position)
      nested_ticket_field = ticket_field.nested_ticket_fields.find(nested_field.delete(:id))
      @invalid_fields.push(ticket_field) and return unless nested_ticket_field.update_attributes(nested_field)
    end

    def get_choices(field)
      case field.field_type
        when "nested_field" then
          field.nested_choices
        when "default_status" then
          Helpdesk::TicketStatus.statuses_list(current_account)
        else
          field.choices
      end
    end
end
