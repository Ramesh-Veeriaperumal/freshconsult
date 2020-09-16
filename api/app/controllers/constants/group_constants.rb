module GroupConstants
  ARRAY_FIELDS = ['agent_ids'].freeze

  UPDATE_FIELDS = %w(name description escalate_to unassigned_for auto_ticket_assign).freeze | ARRAY_FIELDS

  UPDATE_FIELDS_WITHOUT_TICKET_ASSIGN = %w(name description escalate_to unassigned_for agent_ids).freeze | ARRAY_FIELDS
  
  FIELDS = %w(group_type).freeze | ARRAY_FIELDS | UPDATE_FIELDS

  FIELDS_WITHOUT_TICKET_ASSIGN = %w(name description escalate_to unassigned_for agent_ids group_type).freeze | ARRAY_FIELDS

  UNASSIGNED_FOR_MAP = { '30m' => 1800, '1h' => 3600, '2h' => 7200, '4h' => 14_400,
                         '8h' => 28_800, '12h' => 43_200, '1d' => 86_400, '2d' => 172_800, '3d' => 259_200, nil => 1800 }.freeze

  ATTRIBUTES_TO_BE_STRIPPED = %w(name).freeze

  UNASSIGNED_FOR_ACCEPTED_VALUES = UNASSIGNED_FOR_MAP.keys.compact.freeze

  SUPPORT_GROUP_NAME = 'support_agent_group'

  FIELD_GROUP_NAME = 'field_agent_group'

  GROUPS_AGENTS_MAPPING = { SUPPORT_GROUP_NAME => Agent::SUPPORT_AGENT, FIELD_GROUP_NAME => Agent::FIELD_AGENT }

  SUPPORT_GROUP_ID = 1

  SUPPORT_AGENT_ID = 1

  OMNI_CHANNEL_FILTER_PARAMS = %w[include auto_assignment].freeze

  INDEX_FIELDS = %w[group_type].freeze | OMNI_CHANNEL_FILTER_PARAMS

  ALLOWED_INCLUDE_PARAMS = %w[omni_channel_groups].freeze

  ACCESSIBLE_FIELDS_FOR_SUPERVISOR= %w(auto_ticket_assign)  

  ASSIGNMENT_TYPES_SANITIZE = {0 => 0, 1 =>1, 2 => 10}

  ROUND_ROBIN_TYPE_SANITIZE= {1 => 1, 2 => 1, 3 => 2, 12 => 12}  

  DB_ASSIGNMENT_TYPE_FOR_MAP = {0 => 0, 1 => 1, 2 => 1, 12 => 1, 10 => 2}   

  UPDATE_PRIVATE_API_FIELDS_WITHOUT_ASSIGNMENT_CONFIG=%w(name description business_hour_id escalate_to unassigned_for agent_ids assignment_type).freeze | ARRAY_FIELDS
  
  PRIVATE_API_FIELDS_WITHOUT_ASSIGNMENT_CONFIG= UPDATE_PRIVATE_API_FIELDS_WITHOUT_ASSIGNMENT_CONFIG | INDEX_FIELDS

  RR_FIELDS = %w(assignment_type round_robin_type capping_limit allow_agents_to_change_availability)

  OCR_FIELDS = %w(assignment_type allow_agents_to_change_availability)

  NO_ASSIGNMENT = 0
  ROUND_ROBIN_ASSIGNMENT = 1
  OMNI_CHANNEL_ROUTING_ASSIGNMENT = 2

  ASSIGNMENT_TYPES=[ NO_ASSIGNMENT, ROUND_ROBIN_ASSIGNMENT, OMNI_CHANNEL_ROUTING_ASSIGNMENT ].freeze

  ROUND_ROBIN = 1
  LOAD_BASED_ROUND_ROBIN = 2
  SKILL_BASED_ROUND_ROBIN = 3
  LBRR_BY_OMNIROUTE = 12

  ROUND_ROBIN_TYPES=[ ROUND_ROBIN, LOAD_BASED_ROUND_ROBIN, SKILL_BASED_ROUND_ROBIN, LBRR_BY_OMNIROUTE ].freeze

  ALLOW_AGENTS_TO_CHANGE_AVAILABILITY = %w[allow_agents_to_change_availability].freeze

  UPDATE_FIELDS_WITH_STATUS_TOGGLE_WITHOUT_TICKET_ASSIGN = UPDATE_FIELDS_WITHOUT_TICKET_ASSIGN | ALLOW_AGENTS_TO_CHANGE_AVAILABILITY

  FIELDS_WITH_STATUS_TOGGLE_WITHOUT_TICKET_ASSIGN = FIELDS_WITHOUT_TICKET_ASSIGN | ALLOW_AGENTS_TO_CHANGE_AVAILABILITY

  UPDATE_FIELDS_WITH_STATUS_TOGGLE = UPDATE_FIELDS | ALLOW_AGENTS_TO_CHANGE_AVAILABILITY

  FIELDS_WITH_STATUS_TOGGLE = FIELDS | ALLOW_AGENTS_TO_CHANGE_AVAILABILITY

  UPDATE_PRIVATE_API_FIELDS_WITH_STATUS_TOGGLE_WITHOUT_ASSIGNMENT_CONFIG = UPDATE_PRIVATE_API_FIELDS_WITHOUT_ASSIGNMENT_CONFIG | ALLOW_AGENTS_TO_CHANGE_AVAILABILITY

  PRIVATE_API_FIELDS_WITH_STATUS_TOGGLE_WITHOUT_ASSIGNMENT_CONFIG = PRIVATE_API_FIELDS_WITHOUT_ASSIGNMENT_CONFIG | ALLOW_AGENTS_TO_CHANGE_AVAILABILITY

  CHANNEL_TASK_ASSIGNMENT_TYPES = {
    default: 0,
    freshchat_omniroute: 21,
    freshchat_intelliassign: 22,
    freshcaller_omniroute: 26
  }.freeze

  # group v2 constants

  KEY_MAPPINGS = { business_hour_id: :business_calendar_id, group_type: :type }.freeze

  ASSIGNMENT_TYPE_MAPPINGS = {
    ROUND_ROBIN => 'round_robin',
    LOAD_BASED_ROUND_ROBIN => 'load_based_round_robin',
    SKILL_BASED_ROUND_ROBIN => 'skill_based_round_robin',
    LBRR_BY_OMNIROUTE => 'lbrr_by_omniroute'
  }.freeze

  OMNI_CHANNEL = 'omni_channel'.freeze

  CHANNEL_SPECIFIC = 'channel_specific'.freeze

  GROUP_V2_INDEX_FIELDS = (%w[type] | INDEX_FIELDS - %w[group_type]).freeze

  CHANNEL_NAMES = { freshdesk: 'ticket' }.freeze
end.freeze
