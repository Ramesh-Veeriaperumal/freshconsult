module CustomFilterConstants
  OPERATORS = %w(is is_in is_greater_than due_by_op).freeze
  EXCLUDED_CONDITIONS = %w(spam deleted).freeze
  QUERY_TYPE_OPTIONS = %w(default custom_field).freeze
  INDEX_FIELDS = [:name, :order_by, :order_type, :per_page, :query_hash, visibility: [:visibility, :group_id]].freeze

  # TODO: nr_due_by
  CONDITIONAL_FIELDS = ['responder_id', 'group_id', 'created_at', 'due_by', 'fr_due_by', 'status',
                        'priority', 'ticket_type', 'source', 'association_type', 'helpdesk_tags.name',
                        'owner_id', 'requester_id', 'helpdesk_schema_less_tickets.product_id',
                        'internal_agent_id', 'internal_group_id', 'any_agent_id', 'any_group_id', 'sl_skill_id'].freeze

  # TODO: nr_due_by
  FEATURE_BASED_CONDITIONAL_FIELDS = [
    ['internal_agent_id', :shared_ownership, 'Shared Ownership'],
    ['internal_group_id', :shared_ownership, 'Shared Ownership'],
    ['any_agent_id',      :shared_ownership, 'Shared Ownership'],
    ['any_group_id',      :shared_ownership, 'Shared Ownership'],
    ['due_by',            :sla_management_v2, 'Sla Management v2'],
    ['fr_due_by',         :sla_management_v2, 'Sla Management v2']
  ].freeze

  FEATURES_KEYS_BY_FIELD   = Hash[*FEATURE_BASED_CONDITIONAL_FIELDS.map { |i| [i[0], i[1]] }.flatten]
  FEATURES_NAMES_BY_FILED  = Hash[*FEATURE_BASED_CONDITIONAL_FIELDS.map { |i| [i[0], i[2]] }.flatten]

  REMOVE_QUERY_HASH = ['spam', 'deleted', 'monitored_by'].freeze
  REMOVE_QUERY_CONDITIONS = ['spam', 'deleted'].freeze

  WF_PREFIX_PARAM_MAPPING = {
    order: :order_by,
    order_type: :order_type,
    per_page: :per_page
  }.freeze

  ARRAY_VALUED_OPERATORS = ['is_in', 'due_by_op'].freeze

  QUERY_HASH_PARAMS = [:condition, :operator, :type, :value, :ff_name].freeze
end
