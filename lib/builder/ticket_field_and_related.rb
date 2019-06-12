# Base Builder for building ticket field and related sub fields.
# Except this, none other files are supposed to be builder pattern.
# But added for ease of navigation under same folder.
class Builder::TicketFieldAndRelated
  attr_reader :ticket_field, :request_params, :account

  def initialize(request_params, account)
    @request_params = request_params
    @account = account
  end

  def build
    build_ticket_field_and_flexifield_def_entry
    build_choices if custom_dropdown_field? || nested_field?
    build_nested_fields_and_child_levels if nested_field?
    ticket_field
  end

  private

    def build_ticket_field_and_flexifield_def_entry
      @ticket_field = Builder::TicketField::CustomField.new(request_params, account).build_ticket_field_and_flexifield_def_entry
    end

    def build_choices
      if custom_dropdown_field?
        Builder::Choices::CustomDropdown.new(ticket_field).build_new_choices(request_params['choices'])
      elsif nested_field?
        Builder::Choices::NestedField.new(ticket_field).build_new_choices(request_params['choices'])
      end
    end

    def build_nested_fields_and_child_levels
      request_params['nested_ticket_fields'].each_with_index do |nested_field_param, index|
        nested_field, child_level = build_nested_field_and_child_level(nested_field_param.merge(level: index + 2))
        associate_ticket_field_and_related_objects(ticket_field, nested_field, child_level)
      end
    end

    def build_nested_field_and_child_level(request_params)
      nested_field = Helpdesk::NestedTicketField.new(nested_field_api_input(request_params))
      child_level = Builder::TicketField::ChildLevel.new(request_params.merge(position: request_params[:level] - 1, type: 'nested_field'), account).build_ticket_field_and_flexifield_def_entry
      nested_field.flexifield_def_entry = child_level.flexifield_def_entry
      [nested_field, child_level]
    end

    def custom_dropdown_field?
      request_params['type'] == 'custom_dropdown'
    end

    def nested_field?
      request_params['type'] == 'nested_field'
    end

    def nested_field_api_input(request_params)
      {
        account_id: account.id,
        label: request_params[:label],
        label_in_portal: request_params[:label_in_portal] || request_params[:label],
        description: request_params[:description] || '',
        level: request_params[:level],
        name: Helpdesk::TicketField.field_name(request_params['label'], account.id)
      }
    end

    def associate_ticket_field_and_related_objects(ticket_field, nested_field, child_level)
      ticket_field.nested_ticket_fields << nested_field
      ticket_field.child_levels << child_level
    end
end
