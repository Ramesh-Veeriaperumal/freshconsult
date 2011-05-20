class Helpdesk::SlaDetail < ActiveRecord::Base
  set_table_name "helpdesk_sla_details" 
  
  belongs_to :sla_policy, :class_name => "Helpdesk::SlaPolicy"
  has_one :account , :through => :sla_policy 
    
  RESPONSETIME = [
    [ :half,    "30 Minutes",  1800 ], 
    [ :one,     "1 Hour",      3600 ], 
    [ :two,     "2 Hours",      7200 ], 
    [ :four,    "4 Hours",     14400 ], 
    [ :eight,   "8 Hours",     28800 ], 
    [ :twelve,  "12 Hours",    43200 ], 
    [ :day,     "1 Day",      86400 ],
    [ :twoday,  "2 Days",     172800 ], 
    [ :threeday,"3 Days",     259200 ], 
   
   
  ]

  RESPONSETIME_OPTIONS = RESPONSETIME.map { |i| [i[1], i[2]] }
  RESPONSETIME_NAMES_BY_KEY = Hash[*RESPONSETIME.map { |i| [i[2], i[1]] }.flatten]
  RESPONSETIME_KEYS_BY_TOKEN = Hash[*RESPONSETIME.map { |i| [i[0], i[2]] }.flatten]
  
  RESOLUTIONTIME = [
    [ :half,    "30 Minutes",  1800 ], 
    [ :one,     "1 Hour",      3600 ], 
    [ :two,     "2 Hours",      7200 ], 
    [ :four,    "4 Hours",     14400 ], 
    [ :eight,   "8 Hours",     28800 ], 
    [ :twelve,  "12 Hours",    43200 ], 
    [ :day,     "1 Day",      86400 ],
    [ :twoday,  "2 Days",     172800 ], 
    [ :threeday,"3 Days",     259200 ], 
   
   
  ]


  RESOLUTIONTIME_OPTIONS = RESOLUTIONTIME.map { |i| [i[1], i[2]] }
  RESOLUTIONTIME_NAMES_BY_KEY = Hash[*RESOLUTIONTIME.map { |i| [i[2], i[1]] }.flatten]
  RESOLUTIONTIME_KEYS_BY_TOKEN = Hash[*RESOLUTIONTIME.map { |i| [i[0], i[2]] }.flatten]
  
  PRIORITIES = [
    [ 'low',       "Low",         1 ], 
    [ 'medium',    "Medium",      2 ], 
    [ 'high',      "High",        3 ], 
    [ 'urgent',    "Urgent",      4 ], 
   
  ]

  PRIORITY_OPTIONS = PRIORITIES.map { |i| [i[1], i[2]] }
  PRIORITY_NAMES_BY_KEY = Hash[*PRIORITIES.map { |i| [i[2], i[0]] }.flatten]
  PRIORITY_KEYS_BY_TOKEN = Hash[*PRIORITIES.map { |i| [i[0], i[2]] }.flatten]
  
  SLA_TIME = [
    [ :business,       "Business Hours",      false ], 
    [ :calendar,    "Calendar Hours",      true ],        
  ]

  SLA_TIME_OPTIONS = SLA_TIME.map { |i| [i[1], i[2]] }
  SLA_TIME_BY_KEY = Hash[*SLA_TIME.map { |i| [i[2], i[0]] }.flatten]
  SLA_TIME_BY_TOKEN = Hash[*SLA_TIME.map { |i| [i[0], i[2]] }.flatten]
  
   
end
