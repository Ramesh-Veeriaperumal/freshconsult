module Helpdesk::Filters::TicketFilterTransformationConstants
  DUE_BY_MAPPING = {
    '1' => 'overdue',
    '2' => 'today',
    '3' => 'tomorrow',
    '4' => 'due_in_eight',
    '5' => 'due_in_four',
    '6' => 'due_in_two',
    '7' => 'due_in_one',
    '8' => 'due_in_half_hour'
  }.freeze

  OPERATOR_MAPPING = {
    spam: 'eq', deleted: 'eq', due_by: 'is_in', frDueBy: 'is_in', nr_due_by: 'is_in'
  }.freeze

  DATA_TYPE_MAPPING = {
    number: ['responder_id', 'group_id', 'sl_skill_id', 'status', 'priority', 'source', 'requester_id', 'association_type', 'owner_id', 'helpdesk_schema_less_tickets.product_id', 'helpdesk_tags.name', 'any_agent_id', 'any_group_id', 'internal_agent_id', 'internal_group_id', 'helpdesk_tickets.display_id', 'helpdesk_subscriptions.user_id', 'article_tickets.article_id', 'solution_articles.user_id', 'helpdesk_tags.id'],
    string: ['ticket_type', 'custom_filter'],
    boolean: ['spam', 'deleted'],
    date_time: ['created_at', 'due_by', 'frDueBy', 'nr_due_by', 'fsm']
  }.freeze

  FILTER_NAME_MAPPING = {
    'owner_id' => 'company_id', 'helpdesk_schema_less_tickets.product_id' => 'product_id',
    'helpdesk_tags.name' => 'tag_id'
  }.freeze
end
