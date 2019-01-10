module SlaPolicyConstants

  MAX_PRIORITY = 4
  
  ASSIGNED_AGENT = -1

  VALID_ESCLATION_TIME = Helpdesk::SlaPolicy::ESCALATION_TIME.map{|i| i[1] }.freeze

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
                    source: { method: "sources", attribute: "" }
                  }.freeze

  ESCALATION_ARRAY_HASH = {
                  "escalation_time" => 'not_included', 
                  "agent_ids" => 'invalid_list'
                }.freeze
  
  VALIDATION_CLASS = 'ApiSlaPolicyValidation'.freeze
  
  ALLOWED_HASH_FIELD = [
                          { 'escalation_time' => [nil] }, 'escalation_time',
                          { 'agent_ids' => [nil] }, 'agent_ids'
                        ].freeze

  ALLOWED_HASH_SLA_TARGET_PRIORITY = [ 
                          {'respond_within' => [nil]}, 'respond_within',
                          {'resolve_within' => [nil]}, 'resolve_within',
                          {'business_hours' => [nil]}, 'business_hours',
                          {'escalation_enabled' => [nil]}, 'escalation_enabled'
                        ].freeze

  ALLOWED_HASH_SLA_TARGET_FIELD =  [
                                      { 'priority_1' => ALLOWED_HASH_SLA_TARGET_PRIORITY }, 'priority_1',
                                      { 'priority_2' => ALLOWED_HASH_SLA_TARGET_PRIORITY }, 'priority_2',
                                      { 'priority_3' => ALLOWED_HASH_SLA_TARGET_PRIORITY }, 'priority_3',
                                      { 'priority_4' => ALLOWED_HASH_SLA_TARGET_PRIORITY }, 'priority_4'
                                    ].freeze

  ALLOWED_HASH_CONDITION_FIELDS = [ { 'company_ids' => [nil] }, 'company_ids', 
                          {'group_ids' => [nil]}, 'group_ids',
                          {'product_ids' => [nil]}, 'product_ids',
                          {'ticket_types' => [nil]}, 'ticket_types',
                          {'sources' => [nil]}, 'sources'
                        ].freeze

  ALLOWED_HASH_ESCALATIONS_RESOLUTION_FIELD =  [
                                      { 'level_1' => ALLOWED_HASH_FIELD }, 'level_1',
                                      { 'level_2' => ALLOWED_HASH_FIELD }, 'level_2',
                                      { 'level_3' => ALLOWED_HASH_FIELD }, 'level_3',
                                      { 'level_4' => ALLOWED_HASH_FIELD }, 'level_4'
                                    ]            

  ALLOWED_HASH_ESCALATIONS_FIELD = [
                                    { 'response' => ALLOWED_HASH_FIELD }, 'response',
                                    { 'resolution' => ALLOWED_HASH_ESCALATIONS_RESOLUTION_FIELD }, 'resolution'
                                  ].freeze                      

  UPDATE_FIELDS = %w(name description active).freeze | 
                  ['sla_target'] | ['sla_target' => ALLOWED_HASH_SLA_TARGET_FIELD] | 
                  ['applicable_to'] | ['applicable_to' => ALLOWED_HASH_CONDITION_FIELDS] | 
                  ['escalation'] | ['escalation' => ALLOWED_HASH_ESCALATIONS_FIELD]
              
  CREATE_FIELDS = UPDATE_FIELDS

end