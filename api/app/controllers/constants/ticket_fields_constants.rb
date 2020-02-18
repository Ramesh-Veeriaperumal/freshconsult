module TicketFieldsConstants
  include CommonFieldsConstants

  NESTED_FIELD = 'nested_field'.freeze
  LABEL_FIELD = 'label'.freeze
  # Used only for the strong_parameters.
  BASIC_ATTRIBUTES = %w[label_for_customers description position required_for_agents
                        required_for_customers customers_can_edit
                        displayed_to_customers required_for_closure].freeze
  NESTED_TICKET_FIELD_ATTRIBUTES = %w[label label_in_portal description].freeze
  CREATE_ATTRIBUTES = %w[type].freeze
  CUSTOM_DROPDOWN_ATTRIBUTES = %w[choices].freeze
  NESTED_FIELD_ATTRIBUTES = %w[nested_ticket_fields].freeze | CUSTOM_DROPDOWN_ATTRIBUTES
  CUSTOM_FIELD_ONLY_ATTRIBUTES = %w[label].freeze
  # SECTION_FIELDS = %w[sections].freeze | CUSTOM_DROPDOWN_FIELDS
  TICKET_ESCAPE_FIELDS = %w[label_in_portal].freeze | ESCAPED_FIELDS
  CUSTOM_DROPDOWN_RELATED_FIELDS = %w[custom_dropdown].freeze
  TYPE_TO_VALIDATION_CLASS = {
      'nested_field' => NestedTicketFieldValidation,
      'custom_dropdown' => BaseChoicesTicketFieldValidation
  }.freeze
  DEFAULT_VALIDATION_CLASS = TicketFieldValidation
  DELEGATOR_CLASS = TicketFieldDelegator
  SECURE_TEXT = 'secure_text'.freeze
end
