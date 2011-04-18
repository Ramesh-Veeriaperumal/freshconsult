module TicketConstants
  
  SOURCES = [
    [ :email,       "Email",            1 ],
    [ :portal,      "Portal",           2 ],
    [ :phone,       "Phone",            3 ],
    [ :forum,       "Forum",            4 ],
    [ :twitter,     "Twitter",          5 ],
    [ :facebook,    "Facebook",         6 ],
  ]

  SOURCE_OPTIONS = SOURCES.map { |i| [i[1], i[2]] }
  SOURCE_NAMES_BY_KEY = Hash[*SOURCES.map { |i| [i[2], i[1]] }.flatten]
  SOURCE_KEYS_BY_TOKEN = Hash[*SOURCES.map { |i| [i[0], i[2]] }.flatten]

  STATUSES = [
    #[ :new,         "New",        1 ], 
    [ :open,        "Open",       2 ], 
    [ :pending,     "Pending",    3 ], 
    [ :resolved,    "Resolved",   4 ], 
    [ :closed,      "Closed",     5 ]
  ]

  STATUS_OPTIONS = STATUSES.map { |i| [i[1], i[2]] }
  STATUS_NAMES_BY_KEY = Hash[*STATUSES.map { |i| [i[2], i[1]] }.flatten]
  STATUS_KEYS_BY_TOKEN = Hash[*STATUSES.map { |i| [i[0], i[2]] }.flatten]
  
  PRIORITIES = [
    [ :low,       "Low",         1 ], 
    [ :medium,    "Medium",      2 ], 
    [ :high,      "High",        3 ], 
    [ :urgent,    "Urgent",      4 ]   
  ]

  PRIORITY_OPTIONS = PRIORITIES.map { |i| [i[1], i[2]] }
  PRIORITY_NAMES_BY_KEY = Hash[*PRIORITIES.map { |i| [i[2], i[1]] }.flatten]
  PRIORITY_KEYS_BY_TOKEN = Hash[*PRIORITIES.map { |i| [i[0], i[2]] }.flatten]
  
  TYPE = [
    [ :how_to,    "Question",             1 ], 
    [ :incident,  "Incident",             2 ], 
    [ :problem,   "Problem",              3 ], 
    [ :f_request, "Feature Request",      4 ],
    [ :lead,      "Lead",                 5 ]   
  ]

  TYPE_OPTIONS = TYPE.map { |i| [i[1], i[2]] }
  TYPE_NAMES_BY_KEY = Hash[*TYPE.map { |i| [i[2], i[1]] }.flatten]
  TYPE_KEYS_BY_TOKEN = Hash[*TYPE.map { |i| [i[0], i[2]] }.flatten]

end