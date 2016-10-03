module CustomFilterConstants

  OPERATORS = %w(is is_in is_greater_than due_by_op).freeze
  EXCLUDED_CONDITIONS = %w(spam deleted).freeze
  QUERY_TYPE_OPTIONS = %w(default custom_field).freeze
  INDEX_FIELDS = [:name, :order, :order_type, :per_page, :query_hash, visibility: [:visibility, :group_id]].freeze

  CONDITIONAL_FIELDS = ['responder_id', 'group_id', 'created_at', 'due_by', 'status', 
    'priority', 'ticket_type', 'source', 'helpdesk_tags.name', 'owner_id', 'requester_id', 
    'helpdesk_schema_less_tickets.product_id'].freeze


  REMOVE_QUERY_HASH = ['spam', 'deleted', 'monitored_by', 'archived'].freeze
  REMOVE_QUERY_CONDITIONS = ['spam', 'deleted'].freeze

  WF_PREFIX = [:order, :order_type, :per_page].freeze

end