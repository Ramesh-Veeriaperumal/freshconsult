module AgentConstants
  LOAD_OBJECT_EXCEPT = %i[create_multiple complete_gdpr_acceptance enable_undo_send disable_undo_send].freeze
  STATES = %w[occasional fulltime].freeze
  INDEX_FIELDS = %w[state email phone mobile only type privilege].freeze
  UPDATE_ARRAY_FIELDS = %w[group_ids role_ids].freeze
  UPDATE_FIELDS = %w[name email phone mobile time_zone job_title language signature ticket_scope occasional shortcuts_enabled].freeze | UPDATE_ARRAY_FIELDS | [ticket_assignment: [:available]].freeze
  CREATE_MULTIPLE_FIELDS = UPDATE_FIELDS
  TICKET_SCOPES = Agent::PERMISSION_TOKENS_BY_KEY.keys
  USER_FIELDS = %w[name email phone mobile time_zone job_title language role_ids].freeze
  VALIDATABLE_DELEGATOR_ATTRIBUTES = %w[agent_role_ids group_ids].freeze
  VALIDATION_CLASS = 'AgentValidation'.freeze
  AGENT_CHANNELS = { ticket_assignment: 'ticket_assignment', chat: 'live_chat', phone: 'freshfone' }.freeze
  ALLOWED_ONLY_PARAMS = %w[available available_count with_privilege].freeze
  FIELD_MAPPINGS = { :"user.primary_email.email" => :email, :"user.base" => :email }.freeze
  IGNORE_PARAMS = %w[shortcuts_enabled ticket_assignment].freeze
  DELEGATOR_CLASS = 'AgentDelegator'.freeze
  AGENTS_USERS_DETAILS = {
    agent_id: 0, user_id: 1, user_name: 2, user_email: 3, agent_type: 4
  }.freeze
  AGENT_GROUPS_ID_MAPPING = {
    user_id: 0, group_id: 1
  }.freeze
  RESTRICTED_PARAMS = ['name', 'job_title', 'phone', 'mobile'].freeze
end.freeze
