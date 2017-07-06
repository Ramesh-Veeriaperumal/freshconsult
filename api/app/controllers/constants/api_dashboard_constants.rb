module ApiDashboardConstants
  ROLE_BASED_SCORECARD_FIELDS = { agent: [:unresolved,:overdue, :due_today, :open, :on_hold],
                       supervisor: [:unresolved, :overdue,  :due_today, :open, :on_hold, :new],
                       admin: [:unresolved, :overdue, :due_today, :open, :on_hold, :new],
                       sprout_17_agent: [:unresolved,:open, :on_hold],
                       sprout_17_supervisor: [:unresolved, :open, :on_hold, :new],
                       sprout_17_admin: [:unresolved, :open, :on_hold, :new] }.freeze
  SPROUT_DASHBOARD = [
    # key, widget name, h,w, group by, order by, limit,
    [:todo,         'todo',                                 2, 2],
    [:activities,   'activity',                             4, 4],  
    [:csat,         'csat',                                 2, 2],
    [:gamification, 'gamification',                         2, 2]
  ].freeze

  AGENT_DASHBOARD = [
    # key, widget name, h,w, group by, order by, limit,
    [:todo,         'todo',                                 2, 2],  
    [:gamification, 'gamification',                         2, 2],
    [:csat,         'csat',                                 2, 2]
  ].freeze

  SUPERVISOR_DASHBOARD = [
    # key, widget name, h,w, group by, order by, limit,
    [:trend_count,  		  'ticket-trends',                      6, 3],
    [:unresolved_tickets, 'unresolved-tickets',                 2, 2],
    [:gamification,   		'gamification',                       2, 2],
    [:csat,           		'csat',                               2, 2],
    [:agent_status,       'agent-status',                       2, 2],
    [:freshfone,      		'phone',                              2, 2],
    [:chat,           		'chat',                               2, 2],
    [:moderation,     		'forum-moderation',                   2, 2],
    [:todo,               'todo',                               2, 2]
  ].freeze

  ADMIN_DASHBOARD = [
     # key, widget name, h,w, group by, order by, limit,
    [:trend_count,        'ticket-trends',                      6, 3],
    [:unresolved_tickets, 'unresolved-tickets',                 2, 2],
    [:gamification,       'gamification',                       2, 2],
    [:csat,               'csat',                               2, 2],
    [:agent_status,       'agent-status',                       2, 2],
    [:freshfone,          'phone',                              2, 2],
    [:chat,               'chat',                               2, 2],
    [:moderation,         'forum-moderation',                   2, 2],
    [:todo,               'todo',                               2, 2]
  ].freeze

  PARAMS_FIELD_NAME_MAPPINGS = { group_ids: :group_id,
                                      product_ids: :product_id,
                                      status_ids: :status,
                                      responder_ids: :responder_id,
                                      internal_groups: :internal_group_id,
                                      internal_agents: :internal_agent_id }.freeze

  ERROR_FIELD_NAME_MAPPINGS = { group_id: :group_ids,
                                  product_id: :product_ids,
                                  status: :status_ids,
                                  responder_id: :responder_ids,
                                  internal_agent_id: :internal_agents,
                                  internal_group_id: :internal_groups }.freeze

  DELEGATOR_PARAM_KEYS_FOR_ACTIONS = {
    unresolved_tickets_data: [:group_id, :responder_id,:status],
    scorecard: [:group_id, :product_id],
    ticket_trends: [:group_id, :product_id],
    ticket_metrics: [:group_id, :product_id]
  }                  

  CSAT_FIELDS = { positive:{label: "positive",value: 0}, neutral: {label: "neutral",value: 0},negative: {label: "negative",value: 0}}.freeze

  ROOT_KEY = {:scorecard => :ticket_summary,
                :show => :dashboards,
                :survey_info => :satisfaction_surveys,
                :moderation_count => :moderation_counts,
                :unresolved_tickets_data => :unresolved_tickets}.freeze

  UNRESOLVED_TICKETS_DATA_FIELDS = %w(group_by group_ids responder_ids status_ids widget).freeze

  TICKET_METRICS_FIELDS = %w(group_ids product_ids).freeze

  TICKET_TRENDS_FIELDS = %w(group_ids product_ids).freeze

  SCORECARD_FIELDS = %w(group_ids product_ids).freeze

  UNRESOLVED_COLUMN_KEY_MAPPING = {:group_id => "group_id", :responder_id => "responder_id", :status => "status", 
      :internal_group_id => "internal_group_id", :internal_agent_id => "internal_agent_id", :group_ids => "group_id", :responder_ids => "responder_id", :status_ids => "status" }.freeze

  UNRESOLVED_FILTER_HEADERS = {
      UNRESOLVED_COLUMN_KEY_MAPPING[:responder_id]      => "agent_label", 
      UNRESOLVED_COLUMN_KEY_MAPPING[:group_id]          => "group_label", 
      UNRESOLVED_COLUMN_KEY_MAPPING[:internal_agent_id] => "internal_agent_label", 
      UNRESOLVED_COLUMN_KEY_MAPPING[:internal_group_id] => "internal_group_label",
      UNRESOLVED_COLUMN_KEY_MAPPING[:status]            => "status_label"
    }.freeze

  UNRESOLVED_GROUP_BY_OPTIONS = [ "group_id", "responder_id"].freeze

  UNRESOLVED_TICKETS_WIDGET_ROW_LIMIT = 4
  
  VALIDATION_CLASS = 'DashboardValidation'.freeze
  DELEGATOR_CLASS = 'DashboardDelegator'.freeze

end
