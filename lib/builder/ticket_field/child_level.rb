# This is the builder used for child level ticket field.
class Builder::TicketField::ChildLevel < Builder::TicketField
  NON_MANDATORY_DEFAULT_FALSE_FIELDS = ['required_for_closure', 'required_for_agents', 'required_for_customers', 'belongs_to_section', 'required_in_portal'].freeze
  NON_MANDATORY_DEFAULT_TRUE_FIELDS = [].freeze

  private

    def type_based_fields_hash
      { level: request_params[:level] }
    end

    def other_non_mandatory_fields_hash
      {
        description: request_params[:description] || '',
        visible_in_portal: input_or_false(request_params[:displayed_to_customers]),
        editable_in_portal: input_or_false(request_params[:customers_can_edit])
      }
    end
end
