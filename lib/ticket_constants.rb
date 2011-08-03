module TicketConstants
  
  CHAT_SOURCES = { :snapengage =>  "snapengage.com", :olark => "olark.com"}
  
  OUT_OF_OFF_SUBJECTS = [ "away from the office", "out of office", "away from office","mail delivery failed","vacation" ]
   
  SOURCES = [
    [ :email,       I18n.t('email'),            1 ],
    [ :portal,     I18n.t('portal_key'),           2 ],
    [ :phone,       I18n.t('phone'),            3 ],
    [ :forum,       I18n.t('forum_key'),            4 ],
    [ :twitter,     I18n.t('twitter'),          5 ],
    [ :facebook,   I18n.t('facebook'),         6 ],
    [ :chat,        I18n.t('chat'),             7 ]
    
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
  
  TYPE = [
    [ :how_to,    I18n.t('how_to'),             1 ], 
    [ :incident,  I18n.t('incident'),             2 ], 
    [ :problem,   I18n.t('problem'),              3 ], 
    [ :f_request, I18n.t('f_request'),      4 ],
    [ :lead,      I18n.t('lead'),                 5 ]   
  ]

  TYPE_OPTIONS = TYPE.map { |i| [i[1], i[2]] }
  TYPE_NAMES_BY_KEY = Hash[*TYPE.map { |i| [i[2], i[1]] }.flatten]
  TYPE_KEYS_BY_TOKEN = Hash[*TYPE.map { |i| [i[0], i[2]] }.flatten]
  
  DEFAULT_COLUMNS =  [
    [ :status, "Status",         :dropdown],
    [ :ticket_type, "Type",         :dropdown],
    [ :responder_id, "Agents",         :dropdown],
    [ :group_id, "Groups",         :dropdown],
    [ :source, "Source",         :dropdown],
    [ :priority, "Priority",         :dropdown]
  ]
  
  DEFAULT_COLUMNS_OPTIONS = Hash[*DEFAULT_COLUMNS.map { |i| [i[0], i[1]] }.flatten]
  DEFAULT_COLUMNS_BY_KEY = Hash[*DEFAULT_COLUMNS.map { |i| [i[2], i[1]] }.flatten]
  DEFAULT_COLUMNS_KEYS_BY_TOKEN = Hash[*DEFAULT_COLUMNS.map { |i| [i[0], i[2]] }.flatten]
 

end