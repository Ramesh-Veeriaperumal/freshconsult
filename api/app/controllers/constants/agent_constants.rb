module AgentConstants
  STATES = %w( occasional fulltime ).freeze
  INDEX_FIELDS = %w( state email phone mobile ).freeze
  UPDATE_ARRAY_FIELDS = %w( group_ids role_ids ).freeze
  UPDATE_FIELDS = %w(name email phone mobile time_zone job_title language signature ticket_scope occasional).freeze | UPDATE_ARRAY_FIELDS
  TICKET_SCOPES = Agent::PERMISSION_TOKENS_BY_KEY.keys
  USER_FIELDS = %w(name email phone mobile time_zone job_title language role_ids).freeze
  VALIDATABLE_DELEGATOR_ATTRIBUTES = %w( agent_role_ids group_ids ).freeze

  FIELD_MAPPINGS = { :"user.primary_email.email" => :email, :"user.base" => :email }.freeze
end.freeze
