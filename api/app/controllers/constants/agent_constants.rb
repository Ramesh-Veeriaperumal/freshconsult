module AgentConstants
  LOAD_OBJECT_EXCEPT = %i[create_multiple complete_gdpr_acceptance enable_undo_send disable_undo_send update_multiple search_in_freshworks verify_agent_privilege availability_count].freeze
  STATES = %w[occasional fulltime].freeze
  INDEX_FIELDS = %w[state email phone mobile only type privilege group_id include order_type order_by].freeze
  UPDATE_ARRAY_FIELDS = %w[group_ids role_ids contribution_group_ids].freeze
  TICKET_SEARCH_SETTINGS = [:include_subject, :include_description, :include_other_properties, :include_notes, :include_attachment_names, :archive].freeze
  UPDATE_FIELDS = %w[name email phone mobile time_zone job_title language signature ticket_scope occasional shortcuts_enabled focus_mode agent_level_id freshcaller_agent avatar_id freshchat_agent].freeze | UPDATE_ARRAY_FIELDS | [ticket_assignment: [:available]].freeze | [search_settings: [tickets: TICKET_SEARCH_SETTINGS]].freeze
  CREATE_FIELDS = %w[name email phone mobile time_zone job_title language signature ticket_scope occasional agent_type agent_level_id freshcaller_agent avatar_id freshchat_agent].freeze | UPDATE_ARRAY_FIELDS | [ticket_assignment: [:available]].freeze
  SKILLS_FIELDS = %w[skill_ids].freeze
  CREATE_MULTIPLE_FIELDS = CREATE_FIELDS
  UPDATE_MULTIPLE_FIELDS = ['id', ticket_assignment: [:available]].freeze
  TICKET_SCOPES = Agent::PERMISSION_TOKENS_BY_KEY.keys
  FIELD_AGENT_SCOPES = Agent::PERMISSIONS_TOKEN_FOR_FIELD_AGENT.keys
  AGENT_TYPES = Agent::PERMISSION_KEYS_FOR_AGENT_TYPES.keys
  USER_FIELDS = %w[name email phone mobile time_zone job_title language role_ids skill_ids].freeze
  AVAILABILITY_COUNT_FIELDS = %w[freshdesk_group_ids freshchat_group_ids freshcaller_group_ids].freeze
  VALIDATABLE_DELEGATOR_ATTRIBUTES = %w[agent_role_ids group_ids].freeze
  VALIDATION_CLASS = 'AgentValidation'.freeze
  DEFAULT_AGENT_TYPE_LIST = {
    support_agent: [:support_agent, 'support_agent'],
    field_agent: [:field_agent, 'field_agent']
  }.freeze
  AGENT_CHANNELS = { ticket_assignment: 'ticket_assignment', chat: 'live_chat', phone: 'freshfone' }.freeze
  ALLOWED_ONLY_PARAMS = %w[available available_count with_privilege].freeze
  ALLOWED_INCLUDE_PARAMS = %w[user_info].freeze
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
  EXPORT_FIELDS = ['response_type', 'fields'].freeze
  RECEIVE_VIA = ['email', 'api'].freeze
  AGENT_EXPORT_FIELDS_WITHOUT_SKILLS = ['name', 'email', 'agent_type', 'ticket_scope', 'roles', 'groups', 'phone', 'mobile', 'language', 'time_zone', 'last_seen'].freeze
  AGENT_EXPORT_FIELDS_WITH_SKILLS =  AGENT_EXPORT_FIELDS_WITHOUT_SKILLS | ['skills'].freeze
  FIELD_TO_CSV_HEADER_MAP = {
    'name' =>         { 'Name' => 'agent_name' },
    'email' =>        { 'Email' => 'agent_email' },
    'agent_type' =>   { 'Agent Type' => 'agent_type' },
    'ticket_scope' => { 'Ticket Scope' => 'ticket_scope' },
    'roles' =>        { 'Roles' => 'agent_roles' },
    'groups' =>       { 'Groups' => 'groups' },
    'phone' =>        { 'Phone' => 'agent_phone' },
    'mobile' =>       { 'Mobile' => 'agent_mobile' },
    'language' =>     { 'Language' => 'agent_language' },
    'time_zone' =>    { 'Time Zone' => 'agent_time_zone' },
    'last_seen' =>    { 'Last Seen' => 'last_active_at' },
    'skills' =>       { 'Skills' => 'skills_name' }
  }.freeze
  EXPORT_TYPE = 'agent'.freeze
  BULK_API_JOBS_CLASS = 'Agent'.freeze
  PREFERENCES_FIELDS = [
    :shortcuts_enabled,
    :shortcuts_mapping,
    :notification_timestamp,
    :show_onBoarding,
    :falcon_ui,
    :undo_send,
    :focus_mode,
    :show_loyalty_upgrade,
    { field_service: [:dismissed_sample_scheduling_dashboard] },
    { search_settings:
      { tickets: [
        :include_subject,
        :include_description,
        :include_other_properties,
        :include_notes,
        :include_attachment_names
      ] } }
  ].freeze
  AGENTS_ORDER_TYPE = ['asc', 'desc'].freeze
  AGENTS_ORDER_BY = ['name', 'last_active_at', 'created_at'].freeze
  BULK_API_PARAMS_LIMIT = 500

  AGENT_CREATE_DELEGATOR_KEY = %i[role_ids group_ids user_attributes agent_type occasional skill_ids agent_level_id contribution_group_ids].freeze
  AGENT_UPDATE_DELEGATOR_KEY = %i[role_ids group_ids available avatar_id user_attributes agent_level_id contribution_group_ids].freeze
end.freeze
