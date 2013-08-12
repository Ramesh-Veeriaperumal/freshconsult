module TicketConstants
  
  CHAT_SOURCES = { :snapengage =>  "snapengage.com", :olark => "olark.com"}

  GROUP_THREAD = "group_thread"
  
  OUT_OF_OFF_SUBJECTS = [ "away from the office", "out of office", "away from office","mail delivery failed","returning your reply to helpdesk message", "vacation" ]
   
  # DATE_RANGE_CSV = 31

  SOURCES = [
    [ :email,      'email',            1 ],
    [ :portal,     'portal_key',       2 ],
    [ :phone,      'phone',            3 ],
    [ :forum,      'forum_key',        4 ],
    [ :twitter,    'twitter_source',   5 ],
    [ :facebook,   'facebook_source',  6 ],
    [ :chat,       'chat',             7 ],
    [ :mobi_help,  'mobi_help',        8 ]
  ]

  SOURCE_OPTIONS = SOURCES.map { |i| [i[1], i[2]] }
  SOURCE_NAMES_BY_KEY = Hash[*SOURCES.map { |i| [i[2], i[1]] }.flatten]
  SOURCE_KEYS_BY_TOKEN = Hash[*SOURCES.map { |i| [i[0], i[2]] }.flatten]
  SOURCE_KEYS_BY_NAME = Hash[*SOURCES.map { |i| [i[1], i[2]] }.flatten]

  PRIORITIES = [
    [ :low,       'low',         1,    '#7ebf00' ], 
    [ :medium,    'medium',      2,    '#008ff9' ], 
    [ :high,      'high',        3,    '#ffb613' ], 
    [ :urgent,    'urgent',      4,    '#de0000' ]   
  ]

  PRIORITY_OPTIONS = PRIORITIES.map { |i| [i[1], i[2]] }
  PRIORITY_NAMES_BY_KEY = Hash[*PRIORITIES.map { |i| [i[2], i[1]] }.flatten]
  PRIORITY_KEYS_BY_TOKEN = Hash[*PRIORITIES.map { |i| [i[0], i[2]] }.flatten]
  PRIORITY_KEYS_BY_NAME = Hash[*PRIORITIES.map { |i| [i[1], i[2]] }.flatten]
  PRIORITY_TOKEN_BY_KEY = Hash[*PRIORITIES.map { |i| [i[2], i[0]] }.flatten]
  PRIORITY_COLOR_BY_KEY = Hash[*PRIORITIES.map { |i| [i[2], i[3]] }.flatten]
  
  TYPE = [
    [ :how_to,    I18n.t('how_to'),          1 ], 
    [ :incident,  I18n.t('incident'),        2 ], 
    [ :problem,   I18n.t('problem'),         3 ], 
    [ :f_request, I18n.t('f_request'),       4 ],
    [ :lead,      I18n.t('lead'),            5 ]   
  ]

  TYPE_OPTIONS = TYPE.map { |i| [i[1], i[2]] }
  TYPE_NAMES_BY_KEY = Hash[*TYPE.map { |i| [i[2], i[1]] }.flatten]
  TYPE_KEYS_BY_TOKEN = Hash[*TYPE.map { |i| [i[0], i[2]] }.flatten]
  TYPE_NAMES_BY_SYMBOL = Hash[*TYPE.map { |i| [i[0], i[1]] }.flatten]
  
  DEFAULT_COLUMNS_ORDER = [ :responder_id, :group_id, :created_at, :due_by, :status, :priority,
    :ticket_type, :source, "helpdesk_tags.name", "users.customer_id",
    :requester_id, "helpdesk_schema_less_tickets.product_id" ]
  
  DEFAULT_COLUMNS =  [
    [ :status,              'status',   :dropdown],
    [ :responder_id,        'responder_id',   :dropdown],
    [ :ticket_type,         'ticket_type',     :dropdown],
    [ :group_id,            'group_id',   :dropdown],
    [ :source,              'source',   :dropdown],
    [ :priority,            'priority', :dropdown],
    [ :due_by,              'due_by',  :due_by],
    [ "helpdesk_tags.name", "tags",     :dropdown],
    [ "users.customer_id",  "customers", :dropdown],
    [ :created_at,          "created_at", :created_at],
    [ :requester_id,        'requester', :requester],
    [ "helpdesk_schema_less_tickets.product_id",'products', :dropdown]
  ]
  
  DEFAULT_COLUMNS_OPTIONS = Hash[*DEFAULT_COLUMNS.map { |i| [i[0], i[1]] }.flatten]
  DEFAULT_COLUMNS_BY_KEY = Hash[*DEFAULT_COLUMNS.map { |i| [i[2], i[1]] }.flatten]
  DEFAULT_COLUMNS_KEYS_BY_TOKEN = Hash[*DEFAULT_COLUMNS.map { |i| [i[0], i[2]] }.flatten]
  
  DUE_BY_TYPES = [
    [ :all_due,         'all_due',               1 ], # If modified, _auto_refresh.html.erb has to be modified.
    [ :due_today,       'due_today',             2 ], # By Shridar.
    [ :due_tomo,        'due_tomo',              3 ], 
    [ :due_next_eight,  'due_next_eight',        4 ]
  ]

  DUE_BY_TYPES_OPTIONS = DUE_BY_TYPES.map { |i| [i[1], i[2]] }
  DUE_BY_TYPES_NAMES_BY_KEY = Hash[*DUE_BY_TYPES.map { |i| [i[2], i[1]] }.flatten]
  DUE_BY_TYPES_KEYS_BY_TOKEN = Hash[*DUE_BY_TYPES.map { |i| [i[0], i[2]] }.flatten]
  DUE_BY_TYPES_NAMES_BY_SYMBOL = Hash[*DUE_BY_TYPES.map { |i| [i[0], i[1]] }.flatten]
  
  CREATED_BY_VALUES = [
    [ :thirt_days,    I18n.t("export_data.thirt_days"),   30 ], 
    [ :seven_days,    I18n.t("export_data.seven_days"),    7 ], 
    [ :twenty_four,   I18n.t("export_data.twenty_four"),   1 ],
    [ :custom_filter, I18n.t("export_data.custom_filter"), 4 ]
  ]

  CREATED_BY_OPTIONS = CREATED_BY_VALUES.map { |i| [i[1], i[2]] }
  CREATED_BY_NAMES_BY_KEY = Hash[*CREATED_BY_VALUES.map { |i| [i[2], i[1]] }.flatten]
  CREATED_BY_KEYS_BY_TOKEN = Hash[*CREATED_BY_VALUES.map { |i| [i[0], i[2]] }.flatten]
  CREATED_BY_NAMES_BY_SYMBOL = Hash[*CREATED_BY_VALUES.map { |i| [i[0], i[1]] }.flatten]
  

  CREATED_WITHIN_VALUES = [
    [ :any_time,         'any_time',        "any_time"], # If modified, _auto_refresh.html.erb has to be modified.
    [ :five_minutes,     'five_minutes',            5 ], # By Shridar.
    [ :ten_minutes,      'fifteen_minutes',        15 ],
    [ :thirty_minutes,   'thirty_minutes',         30 ],
    [ :one_hour,         'one_hour',               60 ],
    [ :four_hour,        'four_hours',            240 ],
    [ :twelve_hour,      'twelve_hours',          720 ],
    [ :twentyfour_hour,  'twentyfour_hours',     1440 ],
    [ :today,            'today',             "today" ],
    [ :yesterday,        'yesterday',     "yesterday" ],
    [ :this_week,        'seven_days',         "week" ],
    [ :this_month,       'thirty_days',       "month" ],
    [ :two_months,       'two_months',   "two_months" ], 
    [ :six_months,       'six_months',   "six_months" ]
  ]

  CREATED_AT_OPTIONS = CREATED_WITHIN_VALUES.map { |i| [i[2], i[1]] }

  STATES_HASH = {
    :closed_at => I18n.t("export_data.closed_at"),
    :resolved_at => I18n.t("export_data.resolved_at"),
    :created_at => I18n.t("export_data.created_at")
  }
  
  ACTIVITY_HASH = {
    :status           =>"create_status_activity",
    :priority         =>"create_priority_activity",
    :source           => "create_source_activity",
    :group_id         => "create_group_activity",
    :deleted          => "create_deleted_activity",
    :responder_id     => "create_assigned_activity",
    :product_id       => "create_product_activity",
    :ticket_type      => "create_ticket_type_activity"
  }

  def self.translate_priority_name(priority)
    I18n.t(PRIORITY_NAMES_BY_KEY[priority])
  end

  def self.priority_list
    Hash[*PRIORITIES.map { |i| [i[2], I18n.t(i[1])] }.flatten]
  end

  def self.priority_names
    PRIORITIES.map { |i| [I18n.t(i[1]), i[2]] }
  end
  
  def self.translate_source_name(source)
    I18n.t(SOURCE_NAMES_BY_KEY[source])
  end

  def self.source_list
    Hash[*SOURCES.map { |i| [i[2], I18n.t(i[1])] }.flatten]
  end

  def self.source_names
    SOURCES.map { |i| [I18n.t(i[1]), i[2]] }
  end

  def self.due_by_list
    Hash[*DUE_BY_TYPES.map { |i| [i[2], I18n.t(i[1])] }.flatten]
  end
  
  def self.created_within_list
    CREATED_WITHIN_VALUES.map { |i| [i[2], I18n.t(i[1])] }
  end
end