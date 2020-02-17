module SlaPolicyConstants

  MAX_PRIORITY = 4
  
  ASSIGNED_AGENT = -1

  VALID_ESCLATION_TIME = Helpdesk::SlaPolicy::ESCALATION_TIME.map{|i| i[1] }.freeze
  VALID_REMINDER_TIME = Helpdesk::SlaPolicy::REMINDER_TIME.map{|i| i[1] }.freeze

  VALID_SLA_LEVEL = Helpdesk::SlaPolicy::ESCALATION_LEVELS

  VALID_SLA_TIME = {
    min_sla_time: 900,
    max_sla_time: 31536000
  }.freeze

  SLA_DETAILS_NAME = {
                      1 => "SLA for low priority",
                      2 => "SLA for medium priority",
                      3 => "SLA for high priority",
                      4 => "SLA for urgent priority"
                    }.freeze

  SLA_POLICY_PARAMS = [:name, :description, :active].freeze

  SLA_CONDITION = {
                    company_id: { method: "companies_from_cache", attribute: "id" },
                    group_id: { method: "groups_from_cache", attribute: "id" },
                    product_id: { method: "products_from_cache", attribute: "id" },
                    ticket_type: { method: "ticket_types_from_cache", attribute: "value" },
                    source: { method: "sources", attribute: "" },
                    contact_segment: { method: "contact_filters_from_cache", attribute: "id" },
                    company_segment: { method: "company_filters_from_cache", attribute: "id" }
                  }.freeze

  ESCALATION_ARRAY_HASH = {
                  "escalation_time" => 'not_included', 
                  "agent_ids" => 'invalid_list'
                }.freeze
  
  VALIDATION_CLASS = 'ApiSlaPolicyValidation'.freeze
  
  ALLOWED_ESCALATION_DETAIL_FIELDS = [
                          { 'escalation_time' => [nil] }, 'escalation_time',
                          { 'agent_ids' => [nil] }, 'agent_ids'
                        ].freeze

  ALLOWED_SLA_TARGET_FIELDS = [
    { 'respond_within' => [nil] }, 'respond_within',
    { 'next_respond_within' => [nil] }, 'next_respond_within',
    { 'resolve_within' => [nil] }, 'resolve_within',
    { 'business_hours' => [nil] }, 'business_hours',
    { 'escalation_enabled' => [nil] }, 'escalation_enabled'
  ].freeze

  ALLOWED_SLA_TARGET_PRIORITY_FIELDS = [
    { 'priority_1' => ALLOWED_SLA_TARGET_FIELDS }, 'priority_1',
    { 'priority_2' => ALLOWED_SLA_TARGET_FIELDS }, 'priority_2',
    { 'priority_3' => ALLOWED_SLA_TARGET_FIELDS }, 'priority_3',
    { 'priority_4' => ALLOWED_SLA_TARGET_FIELDS }, 'priority_4'
  ].freeze

  ALLOWED_CONDITION_FIELDS = [{ 'company_ids' => [nil] }, 'company_ids',
                          {'group_ids' => [nil]}, 'group_ids',
                          {'product_ids' => [nil]}, 'product_ids',
                          {'ticket_types' => [nil]}, 'ticket_types',
                          {'sources' => [nil]}, 'sources',
                          {'contact_segments' => [nil]}, 'contact_segments',
                          {'company_segments' => [nil]}, 'company_segments'
                        ].freeze

  ALLOWED_RESOLUTION_ESCALATION_FIELDS = [
    { 'level_1' => ALLOWED_ESCALATION_DETAIL_FIELDS }, 'level_1',
    { 'level_2' => ALLOWED_ESCALATION_DETAIL_FIELDS }, 'level_2',
    { 'level_3' => ALLOWED_ESCALATION_DETAIL_FIELDS }, 'level_3',
    { 'level_4' => ALLOWED_ESCALATION_DETAIL_FIELDS }, 'level_4'
  ].freeze

  ESCALATION_TYPES_EXCEPT_RESOLUTION = %w(reminder_response reminder_next_response reminder_resolution response next_response).freeze
  ESCALATION_TYPES = (ESCALATION_TYPES_EXCEPT_RESOLUTION + ['resolution']).freeze

  ALLOWED_ESCALATION_FIELDS = [
    { 'reminder_response' => ALLOWED_ESCALATION_DETAIL_FIELDS }, 'reminder_response',
    { 'reminder_next_response' => ALLOWED_ESCALATION_DETAIL_FIELDS }, 'reminder_next_response',
    { 'reminder_resolution' => ALLOWED_ESCALATION_DETAIL_FIELDS }, 'reminder_resolution',
    { 'response' => ALLOWED_ESCALATION_DETAIL_FIELDS }, 'response',
    { 'next_response' => ALLOWED_ESCALATION_DETAIL_FIELDS }, 'next_response',
    { 'resolution' => ALLOWED_RESOLUTION_ESCALATION_FIELDS }, 'resolution'
  ].freeze

  UPDATE_FIELDS = %w(name description active).freeze | 
                  ['sla_target'] | ['sla_target' => ALLOWED_SLA_TARGET_PRIORITY_FIELDS] |
                  ['applicable_to'] | ['applicable_to' => ALLOWED_CONDITION_FIELDS] |
                  ['escalation'] | ['escalation' => ALLOWED_ESCALATION_FIELDS]

  CREATE_FIELDS = UPDATE_FIELDS
  FIELD_ERROR_MAPPINGS = { name: {'has already been taken' => 'duplicate_name_in_sla_policy'} }.freeze

end