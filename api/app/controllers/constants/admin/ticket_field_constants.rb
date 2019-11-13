module Admin::TicketFieldConstants
  NESTED_FIELD = 'nested_field'.freeze
  DEFAULT_PRODUCT = 'default_product'.freeze
  SECTION_PRESENT = 'section_present'.freeze
  DEFAULT_REQUESTER = 'default_requester'.freeze
  PORTALCC = 'portalcc'.freeze
  PORTALCC_TO = 'portalcc_to'.freeze
  HAS_SECTION = 'has_section'.freeze
  PORTAL_CC = 'portal_cc'.freeze
  PORTAL_CC_TO = 'portal_cc_to'.freeze

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

  PICKLIST_COLUMN_MAPPING = {
    id: 5,
    position: 3,
    value: 4,
    parent_choice_id: 1,
    choices: 6 # just be careful, it can change depending on how we fetch columns
  }.freeze

  ALLOWED_FIELD_INSIDE_INCLUDE = %w[section].freeze
  SHOW_FIELDS = %i[include version format id ticket_field].freeze
  INDEX_FIELDS = %i[include version format k].freeze
end
