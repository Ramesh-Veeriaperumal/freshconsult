# This is the builder for the ticket field.
class Builder::TicketField::CustomField < Builder::TicketField
  NON_MANDATORY_DEFAULT_FALSE_FIELDS = ['required_for_closure', 'required_for_agents', 'belongs_to_section'].freeze
  NON_MANDATORY_DEFAULT_TRUE_FIELDS = [].freeze
end
