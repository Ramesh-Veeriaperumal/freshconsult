module TicketConstants
  
  CHAT_SOURCES = { :snapengage =>  "snapengage.com", :olark => "olark.com"}

  MAX_RELATED_TICKETS = 300

  CHILD_TICKETS_PER_ASSOC_PARENT = 10

  BUSINESS_HOUR_CALLER_THREAD = "business_hour"

  NBA_NULL_PRODUCT_ID = "-1"
  
  OUT_OF_OFF_SUBJECTS = [ "away from the office", "out of office", "away from office","mail delivery failed","returning your reply to helpdesk message", "vacation" ]

  # For preventing non-agents from updating inaccessible ticket attibutes
  SUPPORT_PROTECTED_ATTRIBUTES = [ "email", "requester_id", "source", "spam", "deleted",
                                    "tweet_attributes", "fb_post_attributes" ]
   
  # DATE_RANGE_CSV = 31

  SKIPPED_TICKET_CHANGE_ATTRIBUTES = [ :description_html ] #desc_html skipped just to avoid Deprecation Warning

  TICKET_REPLICA = {:first => :old_ticket, :last => :new_ticket}

  STATUS_SLA_TOGGLED_TO = {true => :off, false => :on}

  NEEDED_SBRR_ATTRIBUTES = [:group_id, :status, :responder_id, :spam, :deleted, :sl_skill_id]

  ### Bump the version of "TICKETS_LIST_PAGE_FILTERS" key in fragment_cache/keys.rb when SOURCES are modified.
  SOURCES = [
    [ :email,            'email',            1 ],
    [ :portal,           'portal_key',       2 ],
    [ :phone,            'phone',            3 ],
    [ :forum,            'forum_key',        4 ],
    [ :twitter,          'twitter_source',   5 ],
    [ :facebook,         'facebook_source',  6 ],
    [ :chat,             'chat',             7 ],
    [ :mobihelp,         'mobihelp',         8 ],
    [ :feedback_widget,  'feedback_widget',  9 ],
    [ :outbound_email,   'outbound_email',   10],
	  [ :ecommerce,        'ecommerce',        11 ]
  ]

  SOURCE_OPTIONS = SOURCES.map { |i| [i[1], i[2]] }
  SOURCE_NAMES_BY_KEY = Hash[*SOURCES.map { |i| [i[2], i[1]] }.flatten]
  SOURCE_KEYS_BY_TOKEN = Hash[*SOURCES.map { |i| [i[0], i[2]] }.flatten]
  SOURCE_KEYS_BY_NAME = Hash[*SOURCES.map { |i| [i[1], i[2]] }.flatten]
  SOURCE_TOKEN_BY_KEY = Hash[*SOURCES.map { |i| [i[2], i[0]] }.flatten]

  ### Bump the version of "TICKETS_LIST_PAGE_FILTERS" key in fragment_cache/keys.rb when PRIORITIES are modified.
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

  TICKET_ASSOCIATION = [
    [:assoc_parent,  1],
    [:child,   2],
    [:tracker, 3],
    [:related, 4]
  ]

  TICKET_ASSOCIATION_KEYS_BY_TOKEN = Hash[*TICKET_ASSOCIATION.map { |i| [i[0], i[1]] }.flatten]
  TICKET_ASSOCIATION_TOKEN_BY_KEY = Hash[*TICKET_ASSOCIATION.map { |i| [i[1], i[0]] }.flatten]

  TICKET_ASSOCIATION_FILTER = [
    [ :nil,               'dots',           []],
    [ :assoc_parent,      'assoc_parent',   [TICKET_ASSOCIATION_KEYS_BY_TOKEN[:assoc_parent]]],
    [ :child,             'child',          [TICKET_ASSOCIATION_KEYS_BY_TOKEN[:child]]],
    [ :tracker,           'tracker',        [TICKET_ASSOCIATION_KEYS_BY_TOKEN[:tracker]]],
    [ :related,           'related',        [TICKET_ASSOCIATION_KEYS_BY_TOKEN[:related]]],
    [ :no_association,    'no_association', [-1]]
  ]

  TICKET_ASSOCIATION_FILTER_OPTIONS = TICKET_ASSOCIATION_FILTER.map { |i| [i[1], i[2].join(',')] }
  TICKET_ASSOCIATION_FILTER_NAMES_BY_KEY = Hash[*TICKET_ASSOCIATION_FILTER.map { |i| [i[2].join(','), i[1]] }.flatten]
  TICKET_ASSOCIATION_FILTER_KEYS_BY_TOKEN = Hash[*TICKET_ASSOCIATION_FILTER.map { |i| [i[0], i[2].join(',')] }.flatten]

  DEFAULT_COLUMNS_ORDER = [ :responder_id, :group_id, :created_at, :due_by, :status, :priority,
    :ticket_type, :source, "helpdesk_tags.name", :owner_id,
    :requester_id, :sl_skill_id, "helpdesk_schema_less_tickets.product_id", :association_type ]
  
  ARCHIVE_DEFAULT_COLUMNS_ORDER = [ :responder_id, :group_id, :created_at, :due_by, :status, :priority,
    :ticket_type, :source, "helpdesk_tags.name", "users.customer_id", :owner_id,
    :requester_id, :sl_skill_id, :product_id, :association_type ]

  INTERNAL_AGENT_ID = "internal_agent_id"
  ANY_AGENT_ID      = "any_agent_id"
  INTERNAL_GROUP_ID = "internal_group_id"
  ANY_GROUP_ID      = "any_group_id"

  SHARED_AGENT_COLUMNS_ORDER = [INTERNAL_AGENT_ID, ANY_AGENT_ID]
  SHARED_GROUP_COLUMNS_ORDER = [INTERNAL_GROUP_ID, ANY_GROUP_ID]
  
  DEFAULT_COLUMNS =  [
    [ :status,              'status',           :dropdown],
    [ :responder_id,        'responder_id',     :dropdown],
    [ :ticket_type,         'ticket_type',      :dropdown],
    [ :group_id,            'group_id',         :dropdown],
    [ :source,              'source',           :dropdown],
    [ :priority,            'priority',         :dropdown],
    [ :due_by,              'due_by',           :due_by],
    [ "helpdesk_tags.name", "tags",             :tags],
    [ :owner_id,            "customers",        :customer],
    [ :created_at,          "created_at",       :created_at],
    [ :requester_id,        'requester',        :requester],
    [ :sl_skill_id,         'sl_skill_id',      :dropdown],
    [ "helpdesk_schema_less_tickets.product_id",'products', :dropdown],
    [ :association_type,    'association_type', :dropdown]
  ]
  ARCHIVE_DEFAULT_COLUMNS =  [
    [ :status,              'status',           :dropdown],
    [ :responder_id,        'responder_id',     :dropdown],
    [ :ticket_type,         'ticket_type',      :dropdown],
    [ :group_id,            'group_id',         :dropdown],
    [ :source,              'source',           :dropdown],
    [ :priority,            'priority',         :dropdown],
    [ :due_by,              'due_by',           :due_by],
    [ "helpdesk_tags.name", "tags",             :tags],
    [ "users.customer_id",  "customers",        :customer],
    [ :owner_id,            "customers",        :customer],
    [ :created_at,          "created_at",       :created_at],
    [ :requester_id,        'requester',        :requester],
    [ :sl_skill_id,         'sl_skill_id',      :dropdown],
    [ :product_id,          'products',         :dropdown],
    [ :association_type,    'association_type', :dropdown]
  ]
  
  
  DEFAULT_COLUMNS_OPTIONS = Hash[*DEFAULT_COLUMNS.map { |i| [i[0], i[1]] }.flatten]
  DEFAULT_COLUMNS_BY_KEY = Hash[*DEFAULT_COLUMNS.map { |i| [i[2], i[1]] }.flatten]
  DEFAULT_COLUMNS_KEYS_BY_TOKEN = Hash[*DEFAULT_COLUMNS.map { |i| [i[0], i[2]] }.flatten]

  ARCHIVE_DEFAULT_COLUMNS_OPTIONS = Hash[*ARCHIVE_DEFAULT_COLUMNS.map { |i| [i[0], i[1]] }.flatten]
  ARCHIVE_DEFAULT_COLUMNS_BY_KEY = Hash[*ARCHIVE_DEFAULT_COLUMNS.map { |i| [i[2], i[1]] }.flatten]
  ARCHIVE_DEFAULT_COLUMNS_KEYS_BY_TOKEN = Hash[*ARCHIVE_DEFAULT_COLUMNS.map { |i| [i[0], i[2]] }.flatten]

  FILTER_MODES = {:primary => 0, :internal => 1, :any => 2}

  SHARED_AGENT_COLUMNS = [
    ["internal_agent_id",   :dropdown,          FILTER_MODES[:internal] ],
    ["any_agent_id",        :special_responder, FILTER_MODES[:any] ]
  ]

  SHARED_GROUP_COLUMNS = [
    ["internal_group_id",   :dropdown,          FILTER_MODES[:internal] ],
    ["any_group_id",        :special_responder, FILTER_MODES[:any] ]
  ]

  SHARED_AGENT_COLUMNS_KEYS_BY_TOKEN       = Hash[*SHARED_AGENT_COLUMNS.map { |i| [i[0], i[1]] }.flatten]
  SHARED_AGENT_COLUMNS_CONDITIONS_BY_MODE  = Hash[*SHARED_AGENT_COLUMNS.map { |i| [i[2], i[0]] }.flatten]
  SHARED_AGENT_COLUMNS_MODE_BY_NAME        = Hash[*SHARED_AGENT_COLUMNS.map { |i| [i[0], i[2]] }.flatten]

  SHARED_GROUP_COLUMNS_KEYS_BY_TOKEN       = Hash[*SHARED_GROUP_COLUMNS.map { |i| [i[0], i[1]] }.flatten]
  SHARED_GROUP_COLUMNS_CONDITIONS_BY_MODE  = Hash[*SHARED_GROUP_COLUMNS.map { |i| [i[2], i[0]] }.flatten]
  SHARED_GROUP_COLUMNS_MODE_BY_NAME        = Hash[*SHARED_GROUP_COLUMNS.map { |i| [i[0], i[2]] }.flatten]

  ### Bump the version of "TICKETS_LIST_PAGE_FILTERS" key in fragment_cache/keys.rb when DUE_BY_TYPES are modified.
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

  CREATED_BY_VALUES_EN = [
    [ :thirt_days,    "export_data.thirt_days",   30 ],
    [ :seven_days,    "export_data.seven_days",    7 ],
    [ :twenty_four,   "export_data.twenty_four",   1 ],
    [ :custom_filter, "export_data.custom_filter", 4 ]
  ]

  CREATED_BY_OPTIONS = CREATED_BY_VALUES.map { |i| [i[1], i[2]] }
  CREATED_BY_NAMES_BY_KEY = Hash[*CREATED_BY_VALUES.map { |i| [i[2], i[1]] }.flatten]
  CREATED_BY_KEYS_BY_TOKEN = Hash[*CREATED_BY_VALUES.map { |i| [i[0], i[2]] }.flatten]
  CREATED_BY_NAMES_BY_SYMBOL = Hash[*CREATED_BY_VALUES.map { |i| [i[0], i[1]] }.flatten]
  
  ARCHIVE_EXPORT_VALUES = [
    [ :two_months,       I18n.t('two_months'),   60 ], 
    [ :six_months,       I18n.t('six_months'),   180],
    [ :set_date,         I18n.t('set_date'),     4  ]
  ]
  ARCHIVE_EXPORT_OPTIONS = ARCHIVE_EXPORT_VALUES.map { |i| [i[1], i[2]] }

  ARCHIVE_CREATED_WITHIN_VALUES = [
    [ :any_time,         I18n.t('any_time'),      "any_time"   ],
    [ :two_months,       I18n.t('two_months'),    "two_months" ], 
    [ :six_months,       I18n.t('six_months'),    "six_months" ],
    [ :set_date,         I18n.t('set_date'),      "set_date"   ]
  ]
  ARCHIVE_CREATED_WITHIN_OPTIONS = ARCHIVE_CREATED_WITHIN_VALUES.map { |i| [i[2], i[1]] }

  ### Bump the version of "TICKETS_LIST_PAGE_FILTERS" key in fragment_cache/keys.rb when CREATED_WITHIN_VALUES are modified.
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
    [ :last_week,        'last_seven_days',     "last_week" ],
    [ :this_month,       'thirty_days',       "month" ],
    [ :last_month,       'last_thirty_days',    "last_month"],
    [ :two_months,       'last_sixty_days',   "two_months" ], 
    [ :six_months,       'last_one_eighty_days',   "six_months" ],
    [ :set_date,         'set_date',       "set_date" ]
  ]

  CREATED_AT_OPTIONS = CREATED_WITHIN_VALUES.map { |i| [i[2], i[1]] }

  STATES_HASH = {
    :closed_at => I18n.t("export_data.closed_time"),
    :resolved_at => I18n.t("export_data.resolved_time"),
    :created_at => I18n.t("export_data.created_time")
  }
  
  ACTIVITY_HASH = {
    :status           =>"create_status_activity",
    :priority         =>"create_priority_activity",
    :source           => "create_source_activity",
    :group_id         => "create_group_activity",
    :deleted          => "create_deleted_activity",
    :responder_id     => "create_assigned_activity",
    :product_id       => "create_product_activity",
    :ticket_type      => "create_ticket_type_activity",
    :due_by           => "create_due_by_activity"
  }

  REPORT_TYPE_HASH = {
    :helpdesk_received  => :created_at,
    :group_received     => :created_at,
    :agent_received     => :created_at,
    :customer_received  => :created_at,
    :helpdesk_resolved  => :"helpdesk_ticket_states.resolved_at",
    :group_resolved     => :"helpdesk_ticket_states.resolved_at",
    :agent_resolved     => :"helpdesk_ticket_states.resolved_at",
    :customer_resolved  => :"helpdesk_ticket_states.resolved_at"
  }

  DASHBOARD_FILTER_MAPPING = {
    :agent => "responder_id",
    :group => "group_id",
    :priority => "priority",
    :type => "ticket_type",
    :source => "source",
    :status => "status",
    :requester => "requester_id",
    :company => "owner_id",
    :internal_agent => INTERNAL_AGENT_ID,
    :internal_group => INTERNAL_GROUP_ID
  }

  DEFAULT_FIELDS_ORDER = [
    "default_priority", "default_status",
    "default_source",   "default_ticket_type",
    "default_group",    "default_agent",
    "default_product",  "default_company"
  ]

  SHARED_DEFAULT_FIELDS_ORDER = {
    "default_priority"       => "priority",
    "default_status"         => "status",
    "default_group"          => "group_id",
    "default_agent"          => "responder_id",
    "default_internal_group" => "internal_group_id",
    "default_internal_agent" => "internal_agent_id",
    "default_source"         => "source",
    "default_ticket_type"    => "ticket_type",
    "default_product"        => "product_id",
    "default_company"        => "company_id"
  }

  # CC emails count
  MAX_EMAIL_COUNT = 50

  # Used in redis_display_id feature
  TICKET_START_DISPLAY_ID = -100000000
  TICKET_DISPLAY_ID_MAX_LOOP = 10
  TICKET_ID_LOCK_EXPIRY = 5 #5 seconds

  BACKGROUND_THRESHOLD = 5

  # Used in reports ETL
  VISIBILITY_MAPPING = {
    :active => 1,
    :deleted => 2,
    :spam => 3,
    :merged_ticket => 4
  }

  CHILD_DEFAULT_FD_MAPPING = ["email", "requester_id", "subject", "status", "ticket_type", "group_id", "responder_id",
    "priority", "product_id", "description_html", "tags"]

  DB_INDEXED_QUERY_COLUMNS = ["requester_id", "responder_id", "group_id", "created_at", "status"]

  SKILL_BASED_TICKET_ATTRIBUTES = [:sbrr_ticket_dequeued, :sbrr_user_score_incremented, :sbrr_fresh_ticket, :skip_sbrr, :sbrr_turned_on, :status_sla_toggled_to, :skip_sbrr_assigner]

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

  def self.source_token(key)
    SOURCE_TOKEN_BY_KEY[key]
  end

  def self.due_by_list
    Hash[*DUE_BY_TYPES.map { |i| [i[2], I18n.t(i[1])] }.flatten]
  end
  
  def self.created_within_list
    CREATED_WITHIN_VALUES.map { |i| [i[2], I18n.t(i[1])] }
  end

  #TODO : change the format of the date based on the account config
  def self.created_date_range_default
    "#{1.month.ago.strftime("%d %b %Y")} - #{1.days.ago.strftime("%d %b %Y")}"
  end

  def self.feature_based_association_type
    assoc_parent_child_feature = Account.current.parent_child_tkts_enabled?
    link_tickets_feature = Account.current.link_tkts_enabled?
    return [] unless assoc_parent_child_feature || link_tickets_feature
    list = [TICKET_ASSOCIATION_FILTER[0]]
    if assoc_parent_child_feature
      list << TICKET_ASSOCIATION_FILTER[1]
      list << TICKET_ASSOCIATION_FILTER[2]
    end
    if link_tickets_feature
      list << TICKET_ASSOCIATION_FILTER[3]
      list << TICKET_ASSOCIATION_FILTER[4]
    end
    list << TICKET_ASSOCIATION_FILTER[5]
    list
  end

  def self.association_type_filter_list
    Hash[*feature_based_association_type.map { |i| [i[2].join(','), I18n.t(i[1])] }.flatten]
  end

  def self.association_type_filter_names
    TICKET_ASSOCIATION_FILTER.map { |i| [i[1], i[2].join(',')] }
  end

   def self.created_options
    CREATED_BY_VALUES_EN.map { |i| [I18n.t(i[1]), i[2]] }
  end
end