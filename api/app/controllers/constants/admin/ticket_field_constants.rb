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
  PORTAL_CC_TO_VALUES = %w[all company].freeze
  ALLOWED_HASH_BASIC_CHOICE_FIELDS = %w[id value archived deleted position parent_choice_id choices].freeze

  ALLOWED_STATUS_CHOICES = %i[id label_for_customers value stop_sla_timer archived deleted group_ids position].freeze
  ALLOWED_SOURCE_CHOICES = %i[label position icon_id deleted id].freeze

  ALLOWED_HASH_CHOICES_LEVEL_2 = ALLOWED_HASH_BASIC_CHOICE_FIELDS - %w[choices] |
                                 [choices: ALLOWED_HASH_BASIC_CHOICE_FIELDS]

  ALLOWED_HASH_CHOICES = ALLOWED_HASH_BASIC_CHOICE_FIELDS + ALLOWED_STATUS_CHOICES + ALLOWED_SOURCE_CHOICES |
                         [choices: ALLOWED_HASH_CHOICES_LEVEL_2]

  ALLOWED_HASH_SECTION_MAPPINGS = %i[section_id position deleted].freeze

  DEPENDENT_FIELD_PARAMS_WITH_TYPE = {
    label: String,
    label_for_customers: String,
    level: Integer,
    id: Integer,
    deleted: 'bool'
  }.freeze

  ALLOWED_DEPENDENT_FIELD_PARAMS = %i[label label_for_customers level id deleted].freeze

  CHOICES_EXPECTED_TYPE = {
    id: Integer,
    label_for_customers: String,
    value: String,
    stop_sla_timer: 'bool',
    archived: 'bool',
    deleted: 'bool',
    position: Integer,
    parent_choice_id: Integer,
    choices: [Array, Hash],
    group_ids: [Array, Integer]
  }.freeze

  SOURCE_CHOICES_EXPECTED_TYPE = {
    label: String,
    deleted: 'bool',
    position: Integer,
    icon_id: Integer,
    choices: [Array, Hash],
    id: Integer
  }.freeze

  DATA_TYPE_MAPPING = {
    0.class => 'Integer',
    0.0.class => 'Float',
    "".class => 'String',
    nil.class => 'Null',
    true.class => 'Boolean',
    false.class => 'Boolean',
    [].class => 'Array',
    {}.class => 'key/value pair',
    {}.with_indifferent_access.class => 'key/value pair'
  }.freeze

  SECTION_MAPPING_EXPECTED_TYPE = {
    section_id: Integer,
    position: Integer,
    deleted: 'bool'
  }.freeze

  MANDATORY_CHOICE_PARAM_FOR_PICKLIST_CREATE = %i[value position].freeze
  MANDATORY_CHOICE_PARAM_FOR_STATUS_CREATE = %i[value position].freeze
  MANDATORY_CHOICE_PARAM_FOR_SOURCE_CREATE = %i[label position].freeze

  MANDATORY_PARAM_FOR_SECTION_MAPPING = %i[section_id].freeze

  DEPENDENT_FIELD_MANDATORY_PARAMS = %i[label label_for_customers level].freeze

  UPDATE_DEPENDENT_FIELD_PARAMS = %i[id level].freeze

  ALLOWED_HASH_DEPENDENT_FIELDS = (DEPENDENT_FIELD_MANDATORY_PARAMS + UPDATE_DEPENDENT_FIELD_PARAMS + [:deleted]).uniq.freeze

  ALLOWED_HASH_BASE_FIELDS = %i[label label_for_customers required_for_closure required_for_agents required_for_customers
                                customers_can_edit displayed_to_customers position type section_mappings dependent_fields
                                choices portal_cc portal_cc_to archived].freeze

  UPDATE_FIELDS = CREATE_FIELDS = ALLOWED_HASH_BASE_FIELDS |
                                  %i[dependent_fields section_mappings choices].freeze |
                                  [section_mappings: ALLOWED_HASH_SECTION_MAPPINGS] |
                                  [dependent_fields: ALLOWED_HASH_DEPENDENT_FIELDS] |
                                  [choices: ALLOWED_HASH_CHOICES].freeze

  # TODO: Remove unnecessary parameters
  PERMITTED_PARAMS = ALLOWED_HASH_BASE_FIELDS

  REQUESTER_PORTAL_PARAMS = %i[portal_cc portal_cc_to].freeze

  PICKLIST_TYPE_FIELDS = {
    nested_field: ['dropdown', 'ffs_'],
    custom_dropdown: ['dropdown', 'ffs_']
  }.freeze

  ENCRYPTED_FIELDS = {
    encrypted_text: ['encrypted_text', 'dn_eslt_'],
    secure_text: ['secure_text', 'dn_eslt_']
  }.freeze

  ENCRYPTED_FIELDS_PREFIX_BY_TYPE = ENCRYPTED_FIELDS.each_with_object({}) { |(k, v), hash| hash[k] = v[1] }

  FIELD_TYPE_TO_COL_TYPE_MAPPING = [*{
    custom_text: ['text', 'dn_slt_'],
    custom_paragraph: ['paragraph', 'dn_mlt_'],
    custom_checkbox: ['checkbox', 'ff_boolean'],
    custom_number: ['number', 'ff_int'],
    custom_date: ['date', 'ff_date'],
    custom_date_time: ['date_time', 'ff_date'],
    custom_decimal: ['decimal', 'ff_decimal']
  }, *PICKLIST_TYPE_FIELDS, *ENCRYPTED_FIELDS].to_h.freeze

  TICKET_FIELD_PORTAL_PARAMS = {
    required:             :required_for_agents,
    visible_in_portal:    :displayed_to_customers,
    editable_in_portal:   :customers_can_edit,
    required_in_portal:   :required_for_customers,
    required_for_closure: :required_for_closure
  }.freeze

  NOT_ALLOWED_PORTAL_PARAMS = TICKET_FIELD_PORTAL_PARAMS.invert.keys.freeze

  TICKET_FIELD_UPDATE_PARAMS = {
    label: :label,
    label_in_portal: :label_for_customers,
    position: :position,
    portalcc: :portal_cc,
    portalcc_to: :portal_cc_to,
    deleted: :archived
  }.merge(TICKET_FIELD_PORTAL_PARAMS).freeze

  NESTED_FIELD_UPDATE_PARAMS = {
    label: :label,
    label_for_customers: :label_in_portal
  }.freeze

  TICKET_FIELD_MANDATORY_PARAMS = {
    name:                 :name,
    label:                :label,
    label_in_portal:      :label_for_customers,
    field_type:           :type,
    position:             :position
  }.freeze

  TICKET_FIELD_PARAMS = {
    name:                 :name,
    label:                :label,
    label_in_portal:      :label_for_customers,
    field_type:           :type,
    position:             :position,
    ticket_form_id:       :ticket_form_id,
    column_name:          :column_name,
    flexifield_coltype:   :flexifield_coltype
  }.merge(TICKET_FIELD_PORTAL_PARAMS).freeze

  FLEXIFIELD_PARAMS = {
    flexifield_name:    :column_name,
    flexifield_alias:   :name,
    flexifield_order:   :position,
    flexifield_coltype: :flexifield_coltype,
    flexifield_def_id:  :ticket_form_id
  }.freeze

  SECTION_PARAMS = %i[label choice_ids].freeze

  SECTION_PICKLIST_MAPPING_PARAMS = {
    picklist_value_id: :id,
    picklist_id: :picklist_id
  }.freeze

  TICKET_FIELDS_RESPONSE_HASH = {
    id: :id,
    name: :name,
    label: :i18n_label,
    label_for_customers: :label_in_portal,
    position: :frontend_position,
    type: :field_type,
    default: :default,
    customers_can_edit: :editable_in_portal,
    required_for_closure: :required_for_closure,
    required_for_agents: :required,
    required_for_customers: :required_in_portal,
    displayed_to_customers: :visible_in_portal,
    field_update_in_progress: :update_in_progress?,
    created_at: :created_at,
    updated_at: :updated_at,
    archived: :deleted
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

  NESTED_FIELD_CHILD_LEVEL_CREATE_PARAMS = {
    name:                 :name,
    label:                :label,
    label_in_portal:      :label_for_customers,
    field_type:           :type,
    position:             :position,
    ticket_form_id:       :ticket_form_id,
    column_name:          :column_name,
    flexifield_coltype:   :flexifield_coltype
  }.freeze

  HELPDESK_NESTED_TICKET_FIELD_UPDATE_PARAMS = {
    level: :level,
    label: :label,
    label_in_portal: :label_for_customers
  }.freeze

  HELPDESK_NESTED_TICKET_FIELD_CREATE_PARAMS = {
    name: :name
  }.merge(HELPDESK_NESTED_TICKET_FIELD_UPDATE_PARAMS).freeze

  SECTION_MAPPING_RESPONSE_HASH = {
    section_id: :section_id,
    position: :position
  }.freeze

  STATUS_CHOICES_PARAMS = {
    value: :name,
    label_for_customers: :customer_display_name,
    stop_sla_timer: :stop_sla_timer,
    deleted: :deleted,
    position: :position
  }.invert.freeze

  SOURCE_CHOICES_PARAMS = {
    label: :name,
    deleted: :deleted,
    position: :position,
    default: :default,
    meta: :meta
  }.invert.freeze

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

  BATCH_SIZE_FOR_PICKLIST_VALUES = 100

  PICKLIST_COLUMN_TO_SELECT = %i[value position].freeze
  CHOICE_LIMIT_BEFORE_GOING_BACKGROUND = 100

  DEFAULT_STATUS_CHOICE_IDS = [2, 3, 4, 5].freeze

  DEFAULT_STATUS_CHOICES_PARAMS_ALLOWED = %i[label_for_customers position].freeze

  PENDING_STATUS_CHOICE_ALLOWED_PARAMS = %i[stop_sla_timer].freeze

  DEPENDENT_FIELD_LEVELS = [2, 3].freeze

  SKIP_FSM_FIELD_TYPES = %w[custom_file, custom_date_time].freeze

  SERVICE_TASK_SECTION = 'Service task section'.freeze

  ALLOWED_FIELDS_FOR_DEFAULT_SOURCE_UPDATE = %i[id position].freeze
end
