module Admin::AutomationConstants
  include Admin::Automation::ActionConstants
  include Admin::ConditionConstants
  include Admin::Automation::EventConstants

  VALIDATION_CLASS = 'Admin::AutomationValidation'.freeze

  INDEX_FIELDS = %i[rule_type].freeze

  SHOW_FIELDS = %i[rule_type].freeze

  PERFORMER_TYPES = {
    agent: '1',
    requester: '2',
    agent_or_requester: '3',
    system: '4',
    field_technician: '5',
    field_technician_or_requester: '6'
  }.freeze

  SERVICE_TASK_RESOURCE_TYPES = ['same_ticket', 'ticket'].freeze

  AUTOMATION_FIELDS = {
    dispatcher: [:conditions, :actions],
    observer: [:performer, :events, :conditions, :actions],
    supervisor: [:conditions, :actions],
    service_task_dispatcher: [:conditions, :actions],
    service_task_observer: [:performer, :events, :conditions, :actions]
  }.freeze

  GROUP_ID_FIELD_NAME = 'group_id'.freeze

  RESPONDER_ID_FIELD_NAME = 'responder_id'.freeze

  FIELD_SERVICE_GROUP_ID = 'field_service_group_id'.freeze

  FIELD_SERVICE_RESPONDER_ID = 'field_service_responder_id'.freeze

  ADD_NOTE_ACTION = 'add_note'.freeze

  ADD_NOTE_AND_NOTIFY_FEIELD_TECH = 'add_note_for_field_techician'.freeze

  SAME_TICKET_EVALUATE_ON = 'same_ticket'.freeze

  SEND_EMAIL = {
    agent: 'send_email_to_agent',
    group: 'send_email_to_group',
    field_tech: 'send_email_to_field_tech',
    field_group: 'send_email_to_field_group'
  }

  AUTOMATION_RULE_TYPES = AUTOMATION_FIELDS.keys.freeze

  FIELD_NAME_CHANGE_MAPPING = {
    from_nested_rules: :from_nested_field,
    to_nested_rules: :to_nested_field,
    nested_rules: :nested_fields,
    name: :field_name,
    evaluate_on: :resource_type
  }.freeze

  FIELD_VALUE_CHANGE_MAPPING = {
    ticlet_cc: :ticket_cc,
    tag_ids: :tag_names,
    created_during: :created_at
  }.freeze

  DATE_FIELDS_OPERATOR_MAPPING = {
    greater_than: :after,
    less_than: :before
  }.freeze

  TAGS_OPERATOR_MAPPING = {
    in: :contains_any_of,
    not_in: :contains_none_of,
    and: :contains_all_of
  }.freeze

  CUSTOM_TEXT_FIELD_TYPES = %i[custom_text custom_paragraph].freeze

  DISPLAY_FIELD_NAME_CHANGE = FIELD_VALUE_CHANGE_MAPPING.invert.freeze

  SUPERVISOR_FIELD_MAPPING = { hours_since_created: :created_at }.freeze

  SUPERVISOR_FIELD_VIEW_MAPPING = SUPERVISOR_FIELD_MAPPING.invert.freeze

  BOOLEAN = [true, false].freeze

  TAG_NAMES = 'tag_names'.freeze

  TAGS = %w[tag_names add_tag].freeze

  DEFAULT_TEXT_FIELDS = %i[subject description subject_or_description].freeze

  LANGUAGE_HASH = I18n.available_locales_with_name.each_with_object({}) do |arr, hash|
    hash[arr.last.to_s] = arr.first
  end.freeze

  LANGUAGE_CODES = LANGUAGE_HASH.keys.freeze

  HASH_SUMMARY_CLASS = { 1 => 'Key', 2 => 'Value', 3 => 'Operator', 4 => 'Evaluate_on' }.freeze

  DEFAULT_ANY_NONE = { '' => 'NONE', '--' => 'ANY', '##' => 'ANY_WITHOUT_NONE', -1 => 'ANY' }.freeze

  PRIORITY_MAP = { '--' => 'Any', '1' => 'Low', '2' => 'Medium', '3' => 'High', '4' => 'Urgent' }.freeze

  WEBHOOK_HTTP_METHODS_KEY_VALUE = { '1' => 'GET', '2' => 'POST', '3' => 'PUT', '4' => 'PATCH DELETE' }.freeze

  ACTION_FIELDS_SUMMARY = %i[priority ticket_type status group_id responder_id product_id add_watcher add_tag].freeze

  FIELD_WITH_IDS = %i[priority status group_id responder_id language product_id customer_feedback
                      source add_watcher trigger_webhook request_type add_note internal_agent_id
                      internal_group_id freddy_suggestion segments association_type].freeze

  RESPONDER_ID = 'responder_id'.freeze

  TICKET_ACTION = %w[update delete marked_spam linked].freeze

  TIME_SHEET_ACTION = %w[added updated].freeze

  SUBJECT_DESCRIPTION_FIELDS = %w[subject description subject_or_description].freeze

  DOMAIN = 'domains'.freeze

  NAME = 'name'.freeze

  RENEWAL_DATE = 'renewal_date'.freeze

  COMPANY = 'company'.freeze

  RESPONDER_ACTIONS_ID = [0, -2].freeze

  PERMITTED_ASSOCIATED_FIELDS = %i[field_name operator value].freeze

  DB_FIELD_NAME_CHANGE_MAPPING = FIELD_NAME_CHANGE_MAPPING.inject({}) { |hash, field_mapping| hash.merge!(field_mapping[1] => field_mapping[0]) }

  FIELD_NAME_CHANGE = FIELD_NAME_CHANGE_MAPPING.map { |field_mapping| field_mapping[0] }

  FIELD_VALUE_CHANGE = FIELD_VALUE_CHANGE_MAPPING.keys.freeze

  DB_FIELD_NAME_CHANGE = DB_FIELD_NAME_CHANGE_MAPPING.map { |field_mapping| field_mapping[0] }

  EVENT_NESTED_FIELDS = %i[nested_rules from_nested_rules to_nested_rules from_nested_field to_nested_field].freeze

  EVENT_VALUES_KEY = %i[from to value email_to].freeze
  EVENT_COMMON_FIELDS = EVENT_VALUES_KEY + EVENT_NESTED_FIELDS

  CONDITON_SET_NESTED_FIELDS = %i[nested_fields nested_rules].freeze

  CONDITION_SET_COMMON_FIELDS = %i[evaluate_on operator value rule_type case_sensitive business_hours_id 
                                   custom_status_id associated_fields related_conditions].freeze + CONDITON_SET_NESTED_FIELDS

  ACTION_COMMON_FIELDS = %i[value email_to email_subject email_body request_type
                            url need_authentication username password api_key
                            custom_headers content_layout params nested_rules
                            fwd_to fwd_cc fwd_bcc fwd_note_body evaluate_on
                            show_quoted_text note_body notify_agents resource_type].freeze

  PARENT_CHILD_ASSOCIATION_TYPES = [1, 2].freeze

  DISPATCHER_ACTION_TICKET_ASSOCIATION_TYPES = %w(parent_ticket same_ticket tracker_ticket).freeze

  OBSERVER_ACTION_TICKET_ASSOCIATION_TYPES = %w(parent_ticket same_ticket tracker_ticket).freeze

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

  PERMITTED_PARAMS = %i[name position active performer events conditions operator actions preview custom_ticket_event
                        custom_ticket_action custom_ticket_condition custom_contact_condition custom_company_condition].freeze

  PERMITTED_CONDITION_SET_VALUES = (PERMITTED_DEFAULT_CONDITION_SET_VALUES + %i[case_sensitive rule_type nested_fields 
                                                                                business_hours_id associated_fields
                                                                                associated_ticket_count related_conditions]).freeze

  PERMITTED_EVENTS_PARAMS = %i[field_name from to value rule_type from_nested_field to_nested_field].freeze

  TRANSFORMABLE_EVENT_FIELDS = %i[field_name from_nested_field to_nested_field].freeze

  PERMITTED_PERFORMER_PARAMS = PERFORMER_FIELDS

  PERMITTED_ACTIONS_PARAMS = %i[field_name nested_fields] + ACTION_COMMON_FIELDS

  PERMITTED_NESTED_DATA_PARAMS = %i[field_name] + NESTED_DATA_COMMON_FIELDS

  VA_RULE_ATTRIBUTES = %i[name position active].freeze

  DEFAULT_ACTION_TICKET_FIELDS = %i[priority ticket_type status add_tag add_a_cc trigger_webhook add_watcher
                                    add_comment responder_id product_id internal_agent_id
                                    internal_group_id group_id delete_ticket mark_as_spam
                                    skip_notification forward_ticket add_note].freeze

  SEND_EMAIL_ACTION_FIELDS = %i[send_email_to_group send_email_to_agent send_email_to_requester].freeze

  INTEGRATION_ACTION_FIELDS = %i[marketplace_app_slack_v2 marketplace_app_office_365].freeze

  INTEGRATION_DB_NAME_MAPPING = { marketplace_app_slack_v2: :'Integrations::RuleActionHandler',
                                  marketplace_app_office_365: :'Integrations::Office365ActionHandler' }.freeze

  INTEGRATION_API_NAME_MAPPING = INTEGRATION_DB_NAME_MAPPING.invert.freeze
  INTEGRATION_DB_NAME_VALUE = { marketplace_app_slack_v2: :slack_trigger, marketplace_app_office_365: :office365_trigger }.freeze

  DEFAULT_EVENT_TICKET_FIELDS = %i[priority ticket_type status group_id responder_id note_type reply_sent due_by
                                   ticket_action time_sheet_action customer_feedback].freeze

  SYSTEM_EVENT_FIELDS = %i[mail_del_failed_others mail_del_failed_requester response_due resolution_due next_response_due].freeze

  DEFAULT_CONDITION_TICKET_FIELDS = %i[from_email to_email subject description
                                       priority ticket_type status source product_id responder_id group_id].freeze

  OBSERVER_CONDITION_TICKET_FIELDS = %i[updated_at last_interaction subject_or_description internal_agent_id
                                        internal_group_id tag_ids tag_names association_type associated_ticket_count].freeze

  OBSERVER_CONDITION_FREDDY_FIELD = %i[freddy_suggestion].freeze

  DISPATCHER_CONDITION_TICKET_FIELDS = %i[created_at ticket_cc subject_or_description internal_agent_id
                                          internal_group_id tag_ids ticlet_cc tag_names created_during
                                          association_type].freeze

  SUPERVISOR_CONDITION_TICKET_FIELDS = %i[contact_name company_name].freeze

  SEND_EMAIL_FIELDS = %i[send_email_to_group send_email_to_agent send_email_to_requester].freeze

  ANY_NONE = { NONE: '', ANY: '--', ANY_WITHOUT_NONE: '##' }.freeze

  CHECKBOX_OPERATORS = %w[selected not_selected].freeze

  CONDITION_SET_PARAMS = %i[ticket contact company].freeze

  RESOURCE_TYPES = %i[ticket contact company].freeze

  DELEGATOR_IGNORE_CONTACT_FIELDS = %i[segments email name domain job_title].freeze

  CUSTOM_FILEDS_WITH_CHOICES = %i[nested_field dropdown dropdown_blank checkbox].freeze

  # Supervisor contact and company value
  SUPERVISOR_CONDITION_FIELDS = %i[contact_name company_name].freeze

  # Supervisor only
  TIME_BASED_FILTERS = %i[hours_since_created pending_since resolved_at closed_at opened_at
                          first_assigned_at assigned_at requester_responded_at
                          agent_responded_at frDueBy due_by hours_since_waiting_on_custom_status].freeze
  TIME_AND_STATUS_BASED_FILTER = ['hours_since_waiting_on_custom_status'].freeze
  # Supervisor + Observer
  TICKET_STATE_FILTERS = %i[inbound_count outbound_count].freeze

  # Observer + Dispatcher
  CONDITION_CONTACT_FIELDS = %i[email name job_title time_zone language segments twitter_profile_status twitter_followers_count].freeze

  # Observer + Dispatcher
  CONDITION_COMPANY_FIELDS = %i[name domains segments].freeze

  # Observer + Dispatcher + Based on feature
  TAM_COMPANY_FIELDS = %i[health_score account_tier industry renewal_date].freeze

  COMPANY_FIELDS = %i[name domains].freeze + TAM_COMPANY_FIELDS

  VA_ATTRS = %i[name position last_updated_by active performer events conditions actions].freeze

  FROM_TO = %i[from to].freeze

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

  ACTIONS_HASH = { fields_name: { data_type: { rules: String, presence: true } },
                   value: { presence: true },
                   resource_type: { data_type: { rules: String, presence: true } }
                  }.freeze

  EVENTS_HASH = { field_name: { data_type: { rules: String, allow_nil: false } },
                  from: { data_type: { rules: String, allow_nil: false } },
                  to: { data_type: { rules: String, allow_nil: false } } }.freeze

  PERFORMER_HASH = { type: { data_type: { rules: Integer } }, members: { data_type: { rules: Array },
                                                                         array: { data_type: { rules: Integer } } } }.freeze

  MAXIMUM_CONDITIONAL_SET_COUNT = 2

  WEBHOOK_PERMITTED_PARAMS = %w[field_name request_type url content_layout content_type
                                auth_header custom_headers content resource_type].freeze

  WEBHOOK_HTTP_METHODS = %i[GET POST PUT PATCH DELETE].freeze

  WEBHOOK_CONTENT_TYPE = %i[JSON XML X-FORM-URLENCODED].freeze

  WEBHOOK_AUTH_HEADER_KEY = %w[username password api_key].freeze

  SEND_EMAIL_TO_PARAMS = %i[field_name email_to email_subject email_body].freeze

  ADD_NOTE_PARAMS = %i[field_name notify_agents note_body].freeze

  FORWARD_TICKET_PARAMS = %i[fwd_to fwd_cc fwd_bcc fwd_note_body show_quoted_text].freeze

  MATCH_TYPE_NAME = %i[match_type].freeze

  EVENT_REQUEST_PRAMS = %i[field_name from to value from_nested_field to_nested_field].freeze

  CONDITIONS_REQUEST_PRAMS = %i[condition_set_1 operator condition_set_2].freeze

  MAP_CONDITION_SET_OPERATOR = { or: 'any', and: 'all' }.freeze

  DEFAULT_CONDITION_SET_OPERATOR = 'condition_set_1 and condition_set_2'.freeze

  READABLE_OPERATOR = { 'any' => 'or', 'all' => 'and' }.freeze

  CONDITION_SET_REQUEST_PARAMS = %i[match_type ticket contact company].freeze

  CONDITION_SET_DEFAULT_PARAMS = %i[name match_type properties].freeze

  CONDITION_PROPERTIES_REQUEST_PARAMS = %i[resource_type field_name operator value].freeze

  SUPERVISOR_IGNORE_CONDITION_PARAMS = %i[contact company].freeze

  CONDITION_SET_REQUEST_VALUES = (CONDITION_SET_PROPERTIES + %i[nested_fields case_sensitive business_hours_id 
                                                                custom_status_id associated_fields related_conditions]).freeze

  MARKETPLACE_INTEGRATION_PARAMS = %i[push_to slack_text office365_text].freeze

  ACTION_REQUEST_PRAMS = (%i[field_name value nested_fields resource_type] + WEBHOOK_PERMITTED_PARAMS + SEND_EMAIL_TO_PARAMS +
                         FORWARD_TICKET_PARAMS + ADD_NOTE_PARAMS + MARKETPLACE_INTEGRATION_PARAMS).freeze

  PERFORMER_REQUEST_PRAMS = %i[type members].freeze

  DEFAULT_FIELDS_DELEGATORS = ((%i[priority ticket_type add_watcher status source product_id responder_id group_id
                                   add_tag created_at updated_at note_type ticket_action time_sheet_action
                                   customer_feedback ticket_cc ticlet_cc tag_names tag_ids internal_agent_id
                                   add_note internal_group_id freddy_suggestion hours_since_waiting_on_custom_status]) + SEND_EMAIL_ACTION_FIELDS).freeze

  DELEGATOR_IGNORE_FIELDS = (%i[subject subject_or_description reply_sent trigger_webhook from_email to_email
                                mail_del_failed_requester mail_del_failed_others add_a_cc add_comment delete_ticket
                                mark_as_spam skip_notification due_by from_email to_email ticket_cc last_interaction
                                inbound_count outbound_count description forward_ticket ticlet_cc response_due resolution_due
                                association_type associated_ticket_count next_response_due agent_availability out_of_office out_of_office_days] + (TIME_BASED_FILTERS - %i[hours_since_waiting_on_custom_status]) +
                                SUPERVISOR_CONDITION_TICKET_FIELDS).uniq.freeze

  DEFAULT_FIELDS = (DEFAULT_FIELDS_DELEGATORS + DELEGATOR_IGNORE_FIELDS).freeze

  TIME_BASE_DUPLICATE = %i[created_at_since due_by_since].freeze

  SUPERVISOR_INVLAID_TICKET_FIELD = %i[from_email subject description last_interaction subject_or_description internal_agent_id
                                       internal_group_id tag_ids email name job_title time_zone language segments domain health_score
                                       account_tier industry renewal_date ticket_cc].freeze

  SUMMARY_DEFAULT_FIELDS = (DEFAULT_CONDITION_TICKET_FIELDS + OBSERVER_CONDITION_TICKET_FIELDS + DISPATCHER_CONDITION_TICKET_FIELDS +
                            SUPERVISOR_CONDITION_TICKET_FIELDS + TICKET_STATE_FILTERS + PERMITTED_PARAMS + DEFAULT_ACTION_TICKET_FIELDS +
                            DEFAULT_FIELDS + DEFAULT_EVENT_TICKET_FIELDS + CONDITION_CONTACT_FIELDS + CONDITION_COMPANY_FIELDS +
                            SYSTEM_EVENT_FIELDS + VA_ATTRS + TIME_BASED_FILTERS + SEND_EMAIL_ACTION_FIELDS + TAM_COMPANY_FIELDS + OBSERVER_CONDITION_FREDDY_FIELD).uniq.freeze

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

  FREDDY_ACCEPTED_VALUES = %w[thank_you_note].freeze

  CASE_SENSITIVE_FIELDS = %i[text paragraph].freeze

  NESTED_FIELD_CONSTANTS = {
    from: :from_nested_field,
    to: :to_nested_field,
    value: :nested_fields
  }.freeze

  VALID_DEFAULT_REQUEST_PARAMS_HASH = %i[field_name operator value from to].freeze

  DEFAULT_FIELD_VALUE_TYPE = {
    status: :Integer, priority: :Integer, source: :Integer, responder_id: :Integer, group_id: :Integer,
    internal_group_id: :Integer, internal_agent_id: :Integer, add_watcher: :Integer, product_id: :Integer,
    inbound_count: :Integer, outbound_count: :Integer, customer_feedback: :Integer,
    send_email_to_group: :Integer, send_email_to_agent: :Integer, segments: :Integer,
    association_type: :Integer, associated_ticket_count: :Integer
  }.merge(TIME_BASED_FILTERS.each_with_object({}) do |field, data|
    data[field] = :Integer
  end).freeze

  ARRAY_VALUE_EXPECTING_FIELD = %i[add_watcher].freeze

  DEFAULT_FIELD_VALUE_CONVERTER = DEFAULT_FIELD_VALUE_TYPE.keys.freeze

  PRIVATE_API_ROOT_KEY_MAPPING = {
    1 => :ticket_creation_rule,
    3 => :time_trigger_rule,
    4 => :ticket_update_rule,
    5 => :service_task_creation_rule,
    6 => :service_task_update_rule
  }.freeze

  SUPERVISOR_OPERATOR_CONVERSION_FIELD = %i[status priority source responder_id group_id product_id ticket_type].freeze

  SUPERVISOR_OPERATOR_FROM_TO = {
    is: :in,
    is_not: :not_in,
    in: :in,
    not_in: :not_in
  }.freeze

  CONDITION_NAME_PREFIX = 'condition_set'.freeze

  ADD_COMMENT = 'add_comment'.freeze

  CUSTOMER_FEEDBACK_RATINGS = (CustomSurvey::Survey::CUSTOMER_RATINGS_FACE_VALUE + %w(--)).freeze

  WEBHOOK_ERROR_TYPES = {
    failure: 'failure',
    dropoff: 'dropoff',
    rate_limit: 'rate_limit'
  }.freeze
end.freeze
