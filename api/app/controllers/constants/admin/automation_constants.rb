module Admin::AutomationConstants
  VALIDATION_CLASS = 'Admin::AutomationValidation'.freeze

  INDEX_FIELDS = %i[rule_type].freeze

  SHOW_FIELDS = %i[rule_type].freeze

  AUTOMATION_FIELDS = {
    dispatcher: [:conditions, :actions],
    observer: [:performer, :events, :conditions, :actions],
    supervisor: [:conditions, :actions]
  }.freeze

  AUTOMATION_RULE_TYPES = AUTOMATION_FIELDS.keys.freeze

  FIELD_NAME_CHANGE_MAPPING = {
    from_nested_rules: :from_nested_field,
    to_nested_rules: :to_nested_field,
    nested_rules: :nested_fields,
    name: :field_name
  }.freeze

  FIELD_VALUE_CHANGE_MAPPING = {
    ticlet_cc: :ticket_cc,
    tag_ids: :tag_names,
    created_during: :created_at,
  }.freeze

  DISPLAY_FIELD_NAME_CHANGE = FIELD_VALUE_CHANGE_MAPPING.invert.freeze

  SUPERVISOR_FIELD_MAPPING = { hours_since_created: :created_at }.freeze

  SUPERVISOR_FIELD_VIEW_MAPPING = SUPERVISOR_FIELD_MAPPING.invert.freeze

  BOOLEAN = [true, false].freeze

  TAG_NAMES = 'tag_names'.freeze

  TAGS = %w[tag_names add_tag].freeze

  LANGUAGE_HASH = I18n.available_locales_with_name.each_with_object({}) do |arr, hash|
    hash[arr.last.to_s] = arr.first
  end.freeze

  LANGUAGE_CODES = LANGUAGE_HASH.keys.freeze

  SOURCE = TicketConstants::SOURCE_TOKEN_BY_KEY.inject({}) { |hash, key| hash.merge!(key.first.to_s => key.second.to_s) }.freeze

  SOURCE_BY_ID = TicketConstants::SOURCE_TOKEN_BY_KEY.keys.freeze

  HASH_SUMMARY_CLASS = { 1 => 'Key', 2 => 'Value', 3 => 'Operator', 4 => 'Evaluate_on' }.freeze

  DEFAULT_ANY_NONE = { '' => 'NONE', '--' => 'ANY', '##' => 'ANY_WITHOUT_NONE' }.freeze

  PRIORITY_MAP = { '--' => 'Any', '1' => 'Low', '2' => 'Medium', '3' => 'High', '4' => 'Urgent' }.freeze

  WEBHOOK_HTTP_METHODS_KEY_VALUE = { '1' => 'GET', '2' => 'POST', '3' => 'PUT', '4' => 'PATCH DELETE' }.freeze

  ACTION_FIELDS_SUMMARY = %i[priority ticket_type status group_id responder_id product_id add_watcher add_tag].freeze

  FIELD_WITH_IDS = %i[priority status group_id responder_id language product_id customer_feedback
                      source add_watcher trigger_webhook request_type add_note internal_agent_id
                      internal_group_id].freeze

  RESPONDER_ID = 'responder_id'.freeze

  TICKET_ACTION = %w[added updated].freeze

  TIME_SHEET_ACTION = %w[new_time_entry updated_time_entry].freeze

  DOMAIN = 'domains'.freeze

  NAME = 'name'.freeze

  RENEWAL_DATE = 'renewal_date'.freeze

  COMPANY = 'company'.freeze

  LEVELS = %i[level2 level3].freeze

  DB_FIELD_NAME_CHANGE_MAPPING = FIELD_NAME_CHANGE_MAPPING.inject({}) { |hash, field_mapping| hash.merge!(field_mapping[1] => field_mapping[0]) }

  FIELD_NAME_CHANGE = FIELD_NAME_CHANGE_MAPPING.map { |field_mapping| field_mapping[0] }

  FIELD_VALUE_CHANGE = FIELD_VALUE_CHANGE_MAPPING.keys.freeze

  DB_FIELD_NAME_CHANGE = DB_FIELD_NAME_CHANGE_MAPPING.map { |field_mapping| field_mapping[0] }

  EVENT_NESTED_FIELDS = %i[nested_rules from_nested_rules to_nested_rules from_nested_field to_nested_field].freeze

  EVENT_VALUES_KEY = %i[from to value].freeze
  EVENT_COMMON_FIELDS = EVENT_VALUES_KEY + EVENT_NESTED_FIELDS

  CONDITON_SET_NESTED_FIELDS = %i[nested_fields nested_rules].freeze

  CONDITION_SET_COMMON_FIELDS = %i[operator value rule_type case_sensitive business_hours_id].freeze + CONDITON_SET_NESTED_FIELDS

  ACTION_COMMON_FIELDS = %i[value email_to email_subject email_body request_type
                            url need_authentication username password api_key
                            custom_headers content_layout params nested_rules
                            fwd_to fwd_cc fwd_bcc fwd_note_body
                            show_quoted_text note_body notify_agents].freeze

  NESTED_DATA_COMMON_FIELDS = %i[value operator from to].freeze

  EVENT_FIELDS = %i[name] + EVENT_COMMON_FIELDS

  PERFORMER_FIELDS = %i[type members].freeze

  CONDITION_SET_FIELDS = %i[name] + CONDITION_SET_COMMON_FIELDS

  ACTION_FIELDS = %i[name] + ACTION_COMMON_FIELDS

  NESTED_DATA_FIELDS = %i[name] + NESTED_DATA_COMMON_FIELDS

  EVALUATE_ON_MAPPING = { contact: :requester, company: :company, ticket: :ticket }.freeze

  EVALUATE_ON_MAPPING_INVERT = EVALUATE_ON_MAPPING.invert.freeze

  DEFAULT_OPERATOR = 'all'.freeze

  MASKED_FIELDS = { password: '' }.freeze

  MATCH_TYPE = %w[all any].freeze

  PERMITTED_PARAMS = %i[name position active performer events conditions actions preview custom_ticket_event
                        custom_ticket_action custom_ticket_condition custom_contact_condition custom_company_condition].freeze

  PERMITTED_CONDITION_SET_VALUES = %i[field_name operator value case_sensitive rule_type nested_fields business_hours_id].freeze

  PERMITTED_EVENTS_PARAMS = %i[field_name from to value rule_type from_nested_field to_nested_field].freeze

  TRANSFORMABLE_EVENT_FIELDS = %i[field_name from_nested_field to_nested_field].freeze

  PERMITTED_PERFORMER_PARAMS = PERFORMER_FIELDS

  PERMITTED_ACTIONS_PARAMS = %i[field_name nested_fields] + ACTION_COMMON_FIELDS

  PERMITTED_NESTED_DATA_PARAMS = %i[field_name] + NESTED_DATA_COMMON_FIELDS

  VA_RULE_ATTRIBUTES = %i[name position active].freeze

  DEFAULT_ACTION_TICKET_FIELDS = %i[priority ticket_type status add_tag add_a_cc trigger_webhook add_watcher
                                    add_comment responder_id product_id group_id delete_ticket mark_as_spam
                                    skip_notification forward_ticket add_note].freeze

  SEND_EMAIL_ACTION_FIELDS = %i[send_email_to_group send_email_to_agent send_email_to_requester].freeze

  DEFAULT_EVENT_TICKET_FIELDS = %i[priority ticket_type status group_id responder_id note_type reply_sent due_by
                                   ticket_action time_sheet_action customer_feedback].freeze

  SYSTEM_EVENT_FIELDS = %i[mail_del_failed_others mail_del_failed_requester].freeze

  DEFAULT_CONDITION_TICKET_FIELDS = %i[from_email to_email subject description
                                       priority ticket_type status source product_id responder_id group_id].freeze

  OBSERVER_CONDITION_TICKET_FIELDS = %i[updated_at last_interaction subject_or_description internal_agent_id
                                        internal_group_id tag_ids tag_names].freeze

  DISPATCHER_CONDITION_TICKET_FIELDS = %i[created_at ticket_cc subject_or_description internal_agent_id
                                          internal_group_id tag_ids ticlet_cc tag_names].freeze

  SEND_EMAIL_FIELDS = %i[send_email_to_group send_email_to_agent send_email_to_requester].freeze

  PERFORMER_TYPES = [1, 2, 3, 4].freeze

  ANY_NONE = { NONE: '', ANY: '--', ANY_WITHOUT_NONE: '##' }.freeze

  ANY_NONE_VALUES = ['', '--', '##'].freeze

  CHECKBOX_OPERATORS = %w[selected not_selected].freeze

  MAXIMUM_CONDITION_SET_COUNT = 2

  CONDITION_SET_PARAMS = %i[ticket contact company].freeze

  DELEGATOR_IGNORE_CONTACT_FIELDS = %i[segments email name domain job_title].freeze

  CUSTOM_FILEDS_WITH_CHOICES = %i[nested_field dropdown dropdown_blank checkbox].freeze

  # Supervisor contact and company value
  SUPERVISOR_CONDITION_FIELDS = %i[contact_name company_name].freeze

  # Supervisor only
  TIME_BASED_FILTERS = %i[hours_since_created pending_since resolved_at closed_at opened_at
                          first_assigned_at assigned_at requester_responded_at
                          agent_responded_at frDueBy due_by].freeze

  # Supervisor + Observer
  TICKET_STATE_FILTERS = %i[inbound_count outbound_count].freeze

  # Observer + Dispatcher
  CONDITION_CONTACT_FIELDS = %i[email name job_title time_zone language segments].freeze

  # Observer + Dispatcher
  CONDITION_COMPANY_FIELDS = %i[name domains segments].freeze

  # Observer + Dispatcher + Based on feature
  TAM_COMPANY_FIELDS = %i[health_score account_tier industry renewal_date].freeze

  COMPANY_FIELDS = %i[name domains].freeze + TAM_COMPANY_FIELDS

  VA_ATTRS = %i[name position last_updated_by active performer events conditions actions].freeze

  ACTION_FIELDS_HASH = [
    { name: :priority, field_type: :dropdown, data_type: :Integer }.freeze,
    { name: :ticket_type, field_type: :dropdown, data_type: :String }.freeze,
    { name: :status, field_type: :dropdown, data_type: :Integer }.freeze,
    { name: :add_tag, field_type: :dropdown, data_type: :Array, multiple: true, value: String }.freeze,
    { name: :add_a_cc, field_type: :text, data_type: :String, non_unique_field: true }.freeze,
    { name: :trigger_webhook, field_type: :webhook, data_type: :Integer }.freeze,
    { name: :add_watcher, field_type: :dropdown, value: :Integer, multiple: true, data_type: Array }.freeze,
    { name: :add_comment, field_type: :text, data_type: String, non_unique_field: true }.freeze,
    { name: :responder_id, field_type: :dropdown, data_type: :Integer }.freeze,
    { name: :product_id, field_type: :dropdown, data_type: :Integer }.freeze,
    { name: :group_id, field_type: :dropdown, data_type: :Integer }.freeze,
    { name: :send_email_to_group, field_type: :email, data_type: :Integer }.freeze,
    { name: :send_email_to_agent, field_type: :email, data_type: :Integer }.freeze,
    { name: :send_email_to_requester, field_type: :email, data_type: :Integer }.freeze,
    { name: :add_note, field_type: :add_note_type, data_type: String }.freeze,
    { name: :forward_ticket, field_type: :forward_note, data_type: :Integer }.freeze,
    { name: :delete_ticket, field_type: :label }.freeze,
    { name: :mark_as_spam, field_type: :label }.freeze,
    { name: :skip_notification, field_type: :label }.freeze
  ].freeze

  CUSTOM_FIELD_ACTION_HASH = {
    nested_field: { field_type: :nested_field, data_type: :String }.freeze,
    custom_dropdown: { field_type: :dropdown, data_type: :String }.freeze,
    custom_checkbox: { field_type: :dropdown, data_type: :Integer }.freeze,
    custom_text: { field_type: :text, data_type: :String }.freeze,
    custom_paragraph: { field_type: :text, data_type: :String }.freeze,
    custom_number: { field_type: :text, data_type: :String, allow_any_type: true }.freeze, # data type should be number and should be changed after frontend validation
    custom_decimal: { field_type: :text, data_type: :Float, allow_any_type: true }.freeze, # data type should be number and should be changed after frontend validation
    custom_date: { field_type: :text, data_type: :String }.freeze
  }.freeze

  ACTION_NONE_FIELDS = %i[responder_id product_id group_id].freeze

  EVENT_FIELDS_HASH = [
    { name: :priority, field_type: :dropdown, expect_from_to: true, data_type: :Integer }.freeze,
    { name: :ticket_type, field_type: :dropdown, expect_from_to: true, data_type: :String }.freeze,
    { name: :status, field_type: :dropdown, expect_from_to: true, data_type: :Integer }.freeze,
    { name: :group_id, field_type: :dropdown, expect_from_to: true, data_type: :Integer }.freeze,
    { name: :responder_id, field_type: :dropdown, expect_from_to: true }.freeze,
    { name: :note_type, field_type: :dropdown, expect_from_to: false, data_type: :String }.freeze,
    { name: :reply_sent, field_type: :label, expect_from_to: false }.freeze,
    { name: :due_by, field_type: :label, expect_from_to: false }.freeze,
    { name: :ticket_action, field_type: :dropdown, expect_from_to: false, data_type: :String }.freeze,
    { name: :time_sheet_action, field_type: :dropdown, expect_from_to: false, data_type: :String }.freeze,
    { name: :customer_feedback, field_type: :dropdown, expect_from_to: false, data_type: :Integer }.freeze,
    { name: :mail_del_failed_requester, field_type: :label, expect_from_to: false }.freeze,
    { name: :mail_del_failed_others, field_type: :label, expect_from_to: false }.freeze
  ].freeze

  CUSTOM_FIELD_EVENT_HASH = {
    nested_field: { field_type: :nested_field, data_type: :String, expect_from_to: true, custom_field: true }.freeze,
    custom_dropdown: { field_type: :dropdown, data_type: :String, expect_from_to: true, custom_field: true }.freeze,
    custom_checkbox: { field_type: :dropdown, data_type: :Integer, expect_from_to: false, custom_field: true }.freeze, # need to make integer after frontend validation done
  }.freeze

  EVENT_ANY_FIELDS = %i[priority ticket_type status group_id responder_id note_type customer_feedback].freeze
  EVENT_NONE_FIELDS = %i[group_id responder_id].freeze

  FROM_TO = %i[from to].freeze

  FIELD_TYPE = {
    text: %i[is is_not contains does_not_contain starts_with ends_with is_any_of is_none_of],
    old_text: %i[is is_not contains does_not_contain starts_with ends_with],
    paragraph: %i[is is_not contains does_not_contain starts_with ends_with is_any_of is_none_of],
    email: %i[is is_not contains does_not_contain is_any_of is_none_of],
    old_email: %i[is is_not contains does_not_contain],
    add_note_type: %i[is is_not contains does_not_contain is_any_of is_none_of],
    checkbox: %i[selected not_selected],
    choicelist: %i[in not_in],
    dropdown: %i[in not_in],
    dropdown_blank: %i[in not_in],
    number: %i[is is_not greater_than less_than is_any_of is_none_of],
    decimal: %i[is is_not greater_than less_than],
    hours: %i[is greater_than less_than],
    nested_field: %i[is is_not is_any_of is_none_of],
    supervisor_nested_field: %i[is],
    greater: %i[greater_than],
    object_id: %i[in not_in],
    date_time: %i[during greater_than less_than],
    date: %i[is is_not greater_than less_than],
    tags: %i[in not_in and],
    url: %i[is is_not contains does_not_contain starts_with ends_with is_any_of is_none_of],
    phone_number: %i[is is_not contains does_not_contain starts_with ends_with is_any_of is_none_of]
  }.freeze

  EMAIL_FIELD_TYPE = %i[email old_email].freeze

  SUPERVISOR_FIELD_TYPE = {
      text: :old_text,
      email: :old_email,
      number: :decimal,
      nested_field: :supervisor_nested_field
  }.freeze

  ARRAY_VALUE_EXPECTING_OPERATOR = %i[contains_all_of does_not_contain contains
                                      is_any_of is_none_of in not_in all starts_with ends_with].freeze

  SINGLE_VALUE_EXPECTING_OPERATOR = %i[is is_not greater_than less_than during].freeze

  SUPERVISOR_SINGLE_VALUE_OPERATOR = %i[contains does_not_contain starts_with ends_with].freeze

  NO_VALUE_EXPECTING_OPERATOR = %i[selected not_selected].freeze

  CONDITION_TICKET_FIELDS_HASH = [
    { name: :from_email, field_type: :email, data_type: :String }.freeze,
    { name: :to_email, field_type: :email, data_type: :String }.freeze,
    { name: :ticket_cc, field_type: :email, data_type: :String }.freeze,
    { name: :ticlet_cc, field_type: :email, data_type: :String }.freeze,
    { name: :ticket_type, field_type: :object_id, data_type: :String }.freeze,
    { name: :status, field_type: :object_id, data_type: :Integer }.freeze,
    { name: :priority, field_type: :object_id, data_type: :Integer }.freeze,
    { name: :source, field_type: :object_id, data_type: :Integer }.freeze,
    { name: :product_id, field_type: :object_id, data_type: :Integer }.freeze,
    { name: :group_id, field_type: :object_id, data_type: :Integer }.freeze,
    { name: :responder_id, field_type: :object_id, data_type: :Integer }.freeze,
    { name: :internal_group_id, field_type: :object_id, data_type: :Integer }.freeze,
    { name: :internal_agent_id, field_type: :object_id, data_type: :Integer }.freeze,
    { name: :tag_names, field_type: :tags, data_type: :String }.freeze,
    { name: :subject, field_type: :text, data_type: :String }.freeze,
    { name: :subject_or_description, field_type: :text, data_type: :String }.freeze,
    { name: :description, field_type: :text, data_type: :String }.freeze,
    { name: :last_interaction, field_type: :text, data_type: :String }.freeze,
    { name: :created_at, field_type: :date_time, data_type: :String }.freeze,
    { name: :updated_at, field_type: :date_time, data_type: :String }.freeze,
    { name: :inbound_count, field_type: :number, data_type: :Integer, allow_any_type: true }.freeze,
    { name: :outbound_count, field_type: :number, data_type: :Integer, allow_any_type: true }.freeze,

    { name: :hours_since_created, field_type: :hours, data_type: :Integer }.freeze,
    { name: :pending_since, field_type: :hours, data_type: :Integer }.freeze,
    { name: :resolved_at, field_type: :hours, data_type: :Integer }.freeze,
    { name: :closed_at, field_type: :hours, data_type: :Integer }.freeze,
    { name: :opened_at, field_type: :hours, data_type: :Integer }.freeze,
    { name: :first_assigned_at, field_type: :hours, data_type: :Integer }.freeze,
    { name: :assigned_at, field_type: :hours, data_type: :Integer }.freeze,
    { name: :requester_responded_at, field_type: :hours, data_type: :Integer }.freeze,
    { name: :agent_responded_at, field_type: :hours, data_type: :Integer }.freeze,
    { name: :frDueBy, field_type: :hours, data_type: :Integer }.freeze,
    { name: :due_by, field_type: :hours, data_type: :Integer }.freeze
  ].freeze

  CUSTOM_FIELD_CONDITION_HASH = {
    nested_field: { field_type: :nested_field, data_type: :String, custom_field: true }.freeze,
    custom_dropdown: { field_type: :object_id, data_type: :String, custom_field: true }.freeze,
    custom_checkbox: { field_type: :checkbox, data_type: :String, custom_field: true }.freeze,
    custom_text: { field_type: :text, data_type: :String, custom_field: true }.freeze,
    custom_paragraph: { field_type: :text, data_type: :String, custom_field: true }.freeze,
    custom_number: { field_type: :number, data_type: :String, custom_field: true, allow_any_type: true }.freeze, # data type should be number and should be changed after frontend validation
    custom_decimal: { field_type: :decimal, data_type: :Float, custom_field: true, allow_any_type: true }.freeze, # data type should be number and should be changed after frontend validation
    custom_date: { field_type: :date, data_type: :String, custom_field: true }.freeze,
    custom_date_time: { field_type: :date_time, data_type: :String, custom_field: true }.freeze
  }.freeze

  CONDITION_NONE_FIELDS = %i[ticket_type product_id group_id responder_id internal_group_id
                             internal_agent_id health_score account_tier industry].freeze

  CONDITION_CONTACT_FIELDS_HASH = [
    { name: :email, field_type: :email, data_type: :String }.freeze,
    { name: :name, field_type: :text, data_type: :String }.freeze,
    { name: :job_title, field_type: :text, data_type: :String }.freeze,
    { name: :time_zone, field_type: :choicelist, data_type: :String }.freeze,
    { name: :language, field_type: :choicelist, data_type: :String }.freeze,
    { name: :segments, field_type: :object_id, data_type: :Integer }.freeze
  ].freeze

  CONDITION_COMPANY_FIELDS_HASH = [
    { name: :domains, field_type: :text, data_type: :String }.freeze,
    { name: :name, field_type: :text, data_type: :String }.freeze,
    { name: :segments, field_type: :object_id, data_type: :Integer }.freeze,
    { name: :health_score, field_type: :choicelist, data_type: :String }.freeze,
    { name: :account_tier, field_type: :object_id, data_type: :String }.freeze,
    { name: :industry, field_type: :object_id, data_type: :String }.freeze,
    { name: :renewal_date, field_type: :date, data_type: :String }.freeze
  ].freeze

  CUSTOM_CONDITION_CONTACT_HASH = CUSTOM_CONDITION_COMPANY_HASH = {
    custom_dropdown: { field_type: :dropdown, data_type: :String, custom_field: true }.freeze,
    custom_checkbox: { field_type: :checkbox, data_type: :String, custom_field: true }.freeze,
    custom_text: { field_type: :text, data_type: :String, custom_field: true }.freeze,
    custom_url: { field_type: :url, data_type: :String, custom_field: true }.freeze,
    custom_paragraph: { field_type: :text, data_type: :String, custom_field: true }.freeze,
    custom_number: { field_type: :number, data_type: :String, custom_field: true, allow_any_type: true }.freeze, # data type should be number and should be changed after frontend validation
    custom_phone_number: { field_type: :text, data_type: :String, custom_field: true }.freeze, # data type should be number and should be changed after frontend validation
    custom_date: { field_type: :date, data_type: :String, custom_field: true }.freeze
  }.freeze

  CUSTOM_FIELD_TYPE_HASH = {
    text: String,
    paragraph: String,
    number: Integer,
    decimal: Float,
    phone_number: String
  }.freeze

  ERROR_MESSAGE_DATA_TYPE_MAP = {
    String: :text,
    Integer: :number,
    Date: :date,
    Float: :decimal,
    Array: :list
  }.freeze

  ACTIONS_HASH = { fields_name: { data_type: { rules: String, presence: true } }, value: { presence: true } }.freeze

  EVENTS_HASH = { field_name: { data_type: { rules: String, allow_nil: false } },
                  from: { data_type: { rules: String, allow_nil: false } },
                  to: { data_type: { rules: String, allow_nil: false } } }.freeze

  PERFORMER_HASH = { type: { data_type: { rules: Integer } }, members: { data_type: { rules: Array },
                                                                         array: { data_type: { rules: Integer } } } }.freeze

  EMAIL_VALIDATOR_OPERATORS = [:is, :is_not, :is_any_of, :is_none_of].freeze

  MAXIMUM_CONDITIONAL_SET_COUNT = 2

  WEBHOOK_PERMITTED_PARAMS = %w[field_name request_type url content_layout content_type auth_header custom_headers content].freeze

  WEBHOOK_HTTP_METHODS = %i[GET POST PUT PATCH DELETE].freeze

  WEBHOOK_CONTENT_TYPE = %i[JSON XML X-FORM-URLENCODED].freeze

  WEBHOOK_AUTH_HEADER_KEY = %w[username password api_key].freeze

  SEND_EMAIL_TO_PARAMS = %i[field_name email_to email_subject email_body].freeze

  ADD_NOTE_PARAMS = %i[field_name notify_agents note_body].freeze

  FORWARD_TICKET_PARAMS = %i[fwd_to fwd_cc fwd_bcc fwd_note_body show_quoted_text].freeze

  MATCH_TYPE_NAME = %i[match_type].freeze

  EVENT_REQUEST_PRAMS = %i[field_name from to value from_nested_field to_nested_field].freeze

  CONDITIONS_REQUEST_PRAMS = %i[condition_set_1 operator condition_set_2].freeze

  CONDITION_SET_OPERATOR = %w[or and].freeze

  MAP_CONDITION_SET_OPERATOR = { or: 'any', and: 'all' }.freeze

  READABLE_OPERATOR = { 'any' => 'or', 'all' => 'and' }.freeze

  CONDITION_SET_REQUEST_PARAMS = %i[match_type ticket contact company].freeze

  SUPERVISOR_IGNORE_CONDITION_PARAMS = %i[contact company].freeze

  CONDITION_SET_REQUEST_VALUES = %i[field_name operator value nested_fields case_sensitive business_hours_id].freeze

  ACTION_REQUEST_PRAMS = %i[field_name value nested_fields] + WEBHOOK_PERMITTED_PARAMS + SEND_EMAIL_TO_PARAMS + FORWARD_TICKET_PARAMS + ADD_NOTE_PARAMS

  PERFORMER_REQUEST_PRAMS = %i[type members].freeze

  DEFAULT_FIELDS_DELEGATORS = (%i[priority ticket_type add_watcher status source product_id responder_id group_id
                                  add_tag created_at updated_at note_type ticket_action time_sheet_action
                                  customer_feedback ticket_cc ticlet_cc tag_names tag_ids internal_agent_id
                                  add_note internal_group_id] + SEND_EMAIL_ACTION_FIELDS).freeze

  DELEGATOR_IGNORE_FIELDS = (%i[subject subject_or_description reply_sent trigger_webhook from_email to_email
                                mail_del_failed_requester mail_del_failed_others add_a_cc add_comment delete_ticket
                                mark_as_spam skip_notification due_by from_email to_email ticket_cc last_interaction
                                inbound_count outbound_count description forward_ticket ticlet_cc] + TIME_BASED_FILTERS).uniq.freeze

  DEFAULT_FIELDS = (DEFAULT_FIELDS_DELEGATORS + DELEGATOR_IGNORE_FIELDS).freeze

  TIME_BASE_DUPLICATE = %i[created_at_since due_by_since].freeze

  SUPERVISOR_INVLAID_CONDITION_FIELD = %i[from_email subject description last_interaction subject_or_description internal_agent_id
                                          internal_group_id tag_ids email name job_title time_zone language segments domain health_score
                                          account_tier industry renewal_date ticket_cc].freeze

  SUMMARY_DEFAULT_FIELDS = (DEFAULT_CONDITION_TICKET_FIELDS + OBSERVER_CONDITION_TICKET_FIELDS + DISPATCHER_CONDITION_TICKET_FIELDS +
                            TICKET_STATE_FILTERS + PERMITTED_PARAMS + DEFAULT_ACTION_TICKET_FIELDS + DEFAULT_FIELDS +
                            DEFAULT_EVENT_TICKET_FIELDS + CONDITION_CONTACT_FIELDS + CONDITION_COMPANY_FIELDS + SYSTEM_EVENT_FIELDS +
                            VA_ATTRS + TIME_BASED_FILTERS + SEND_EMAIL_ACTION_FIELDS + TAM_COMPANY_FIELDS).uniq.freeze

  INVALID_SUPERVISOR_CONDITION_CF = %i[text paragraph].freeze

  CHECKBOX_VALUES = [0, 1].freeze

  NEW_ARRAY_VALUE_OPERATOR_MAPPING = {
    contains: :contains,
    does_not_contain: :does_not_contain,
    starts_with: :starts_with,
    ends_with: :ends_with,
    in: :in,
    not_in: :not_in
  }.freeze

  BUSINESS_HOURS_FIELDS = %i[created_at updated_at].freeze

  CASE_SENSITIVE_FIELDS = %i[text paragraph].freeze

  NESTED_LEVEL_COUNT = 2

  NESTED_FIELD_CONSTANTS = {
    from: :from_nested_field,
    to: :to_nested_field,
    value: :nested_field
  }.freeze

  VALID_DEFAULT_REQUEST_PARAMS_HASH = %i[field_name operator value from to].freeze

  CUSTOM_FIELD_NONE_OR_ANY = %i[nested_field dropdown].freeze

  NESTED_EVENT_LABEL = %i[from_nested_field to_nested_field].freeze

  DEFAULT_FIELD_VALUE_TYPE = {
      status: :Integer,
      priority: :Integer,
      source: :Integer,
      responder_id: :Integer,
      group_id: :Integer,
      internal_group_id: :Integer,
      internal_agent_id: :Integer,
      add_watcher: :Integer,
      product_id: :Integer,
      inbound_count: :Integer,
      outbound_count: :Integer
  }.freeze

  ARRAY_VALUE_EXPECTING_FIELD = %i[add_watcher].freeze

  DEFAULT_FIELD_VALUE_CONVERTER = DEFAULT_FIELD_VALUE_TYPE.keys.freeze
end.freeze
