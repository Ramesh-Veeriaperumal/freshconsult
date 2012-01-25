module TicketConstants
  
  CHAT_SOURCES = { :snapengage =>  "snapengage.com", :olark => "olark.com"}
  
  OUT_OF_OFF_SUBJECTS = [ "away from the office", "out of office", "away from office","mail delivery failed","returning your reply to helpdesk message", "vacation" ]
   
  SOURCES = [
    [ :email,      I18n.t('email'),            1 ],
    [ :portal,     I18n.t('portal_key'),       2 ],
    [ :phone,      I18n.t('phone'),            3 ],
    [ :forum,      I18n.t('forum_key'),        4 ],
    [ :twitter,    I18n.t('twitter_source'),   5 ],
    [ :facebook,   I18n.t('facebook_source'),         6 ],
    [ :chat,       I18n.t('chat'),             7 ]    
  ]

  SOURCE_OPTIONS = SOURCES.map { |i| [i[1], i[2]] }
  SOURCE_NAMES_BY_KEY = Hash[*SOURCES.map { |i| [i[2], i[1]] }.flatten]
  SOURCE_KEYS_BY_TOKEN = Hash[*SOURCES.map { |i| [i[0], i[2]] }.flatten]

  STATUSES = [
    #[ :new,         "New",        1 ], 
    [ :open,        I18n.t('open'),       2 ], 
    [ :pending,     I18n.t('pending'),    3 ], 
    [ :resolved,    I18n.t('resolved'),   4 ], 
    [ :closed,      I18n.t('closed'),     5 ]
  ]

  STATUS_OPTIONS = STATUSES.map { |i| [i[1], i[2]] }
  STATUS_NAMES_BY_KEY = Hash[*STATUSES.map { |i| [i[2], i[1]] }.flatten]
  STATUS_KEYS_BY_TOKEN = Hash[*STATUSES.map { |i| [i[0], i[2]] }.flatten]
  
  PRIORITIES = [
    [ :low,       I18n.t('low'),         1 ], 
    [ :medium,    I18n.t('medium'),      2 ], 
    [ :high,      I18n.t('high'),        3 ], 
    [ :urgent,    I18n.t('urgent'),      4 ]   
  ]

  PRIORITY_OPTIONS = PRIORITIES.map { |i| [i[1], i[2]] }
  PRIORITY_NAMES_BY_KEY = Hash[*PRIORITIES.map { |i| [i[2], i[1]] }.flatten]
  PRIORITY_KEYS_BY_TOKEN = Hash[*PRIORITIES.map { |i| [i[0], i[2]] }.flatten]
  PRIORITY_TOKEN_BY_KEY = Hash[*PRIORITIES.map { |i| [i[2], i[0]] }.flatten]
  
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
  
  DEFAULT_COLUMNS_ORDER = [:responder_id,:group_id,:due_by,:status,:priority,:ticket_type,:source,"helpdesk_tags.name","users.customer_id"]
  
  DEFAULT_COLUMNS =  [
    [ :status,              "Status",   :dropdown],
    [ :responder_id,        "Agents",   :dropdown],
    [ :ticket_type,         "Type",     :dropdown],
    [ :group_id,            "Groups",   :dropdown],
    [ :source,              "Source",   :dropdown],
    [ :priority,            "Priority", :dropdown],
    [ :due_by,              "Overdue",  :due_by],
    [ "helpdesk_tags.name", "Tags",     :dropdown],
    [ "users.customer_id",  "Customers", :dropdown],
    #[ :created_at,          "Created At", :created_at]
  ]
  
  DEFAULT_COLUMNS_OPTIONS = Hash[*DEFAULT_COLUMNS.map { |i| [i[0], i[1]] }.flatten]
  DEFAULT_COLUMNS_BY_KEY = Hash[*DEFAULT_COLUMNS.map { |i| [i[2], i[1]] }.flatten]
  DEFAULT_COLUMNS_KEYS_BY_TOKEN = Hash[*DEFAULT_COLUMNS.map { |i| [i[0], i[2]] }.flatten]
  
  DUE_BY_TYPES = [
    [ :all_due,    I18n.t('all_due'),               1 ], 
    [ :due_today,  I18n.t('due_today'),             2 ], 
    [ :due_tomo,   I18n.t('due_tomo'),              3 ], 
    [ :due_next_eight, I18n.t('due_next_eight'),    4 ]
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
  
  
  ACTIVITY_HASH = {
    :status           =>"create_status_activity",
    :priority         =>"create_priority_activity",
    :source           => "create_source_activity",
    :group_id         => "create_group_activity",
    :deleted          => "create_deleted_activity",
    :responder_id     => "create_assigned_activity",
    :email_config_id  => "create_product_activity",
    :ticket_type      => "create_ticket_type_activity"
  }
  
end