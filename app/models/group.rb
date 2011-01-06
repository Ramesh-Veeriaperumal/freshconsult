class Group < ActiveRecord::Base
  
  
  ASSIGNTIME = [
    [ :half,    "30 Minutes",  1800 ], 
    [ :one,     "1 Hour",      3600 ], 
    [ :two,     "2 Hour",      7200 ], 
    [ :four,    "4 Hour",     14400 ], 
    [ :eight,   "8 Hour",     28800 ], 
    [ :two,     "12 Hour",    43200 ], 
    [ :day,     "1 Day",      86400 ],
    [ :twoday,  "2 Day",     172800 ], 
    [ :threeday,"3 Day",     259200 ], 
   
   
  ]

  ASSIGNTIME_OPTIONS = ASSIGNTIME.map { |i| [i[1], i[2]] }
  ASSIGNTIME_NAMES_BY_KEY = Hash[*ASSIGNTIME.map { |i| [i[2], i[1]] }.flatten]
  ASSIGNTIME_KEYS_BY_TOKEN = Hash[*ASSIGNTIME.map { |i| [i[0], i[2]] }.flatten]
  
end
