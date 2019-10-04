module Admin::TicketFieldConstants

  NESTED_FIELD = 'nested_field'
  DEFAULT_PRODUCT = 'default_product'
  SECTION_PRESENT = 'section_present'
  DEFAULT_REQUESTER = 'default_requester'
  PORTALCC = 'portalcc'
  PORTALCC_TO = 'portalcc_to'
  HAS_SECTION = 'has_section'
  PORTAL_CC = 'portal_cc'
  PORTAL_CC_TO = 'portal_cc_to'

  TICKET_FIELDS_RESPONSE_HASH = {
      id: :id,
      name: :name,
      label: :i18n_label,
      label_for_customers: :label_in_portal,
      position: :position,
      type: :field_type,
      default: :default,
      customers_can_edit: :editable_in_portal,
      required_for_closure: :required_for_closure,
      required_for_agents: :required,
      required_for_customers: :required_in_portal,
      displayed_to_customers: :visible_in_portal,
      created_at: :created_at,
      updated_at: :updated_at
  }.freeze

  DEPENDENT_FIELD_RESPONSE_HASH = {
      id: :id,
      name: :name,
      label: :label,
      label_for_customers: :label_in_portal,
      level: :level,
      ticket_field_id: :parent_id,
      created_at: :created_at,
      updated_at: :updated_at
  }.freeze

  SECTION_MAPPING_RESPONSE_HASH = {
      section_id: :section_id,
      position: :position
  }.freeze

end