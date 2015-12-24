module Solution::Constants
	
	STATUSES = [
    [ :draft,     "solutions.status.draft",        1 ], 
    [ :published, "solutions.status.published",    2 ]
  ]
  HITS_CACHE_THRESHOLD = 100
  STATUS_OPTIONS = STATUSES.map { |i| [i[1], i[2]] }
  STATUS_NAMES_BY_KEY = Hash[*STATUSES.map { |i| [i[2], i[1]] }.flatten]
  STATUS_KEYS_BY_TOKEN = Hash[*STATUSES.map { |i| [i[0], i[2]] }.flatten]
  
  TYPES = [
    [ :permanent,  "solutions.types.permanent",   1 ],
    [ :workaround, "solutions.types.workaround",  2 ]
  ]

  TYPE_OPTIONS = TYPES.map { |i| [i[1], i[2]] }
  TYPE_NAMES_BY_KEY = Hash[*TYPES.map { |i| [i[2], i[1]] }.flatten]
  TYPE_KEYS_BY_TOKEN = Hash[*TYPES.map { |i| [i[0], i[2]] }.flatten]
  
  
  SORT_FIELDS = [ 
    [ :created_desc,  'Date Created (Newest First)',    "created_at DESC" ],    
    [ :created_asc,   'Date Created (Oldest First)',    "created_at ASC"  ],    
    [ :updated_desc,  'Last Modified (Newest First)',   "updated_at DESC" ],   
    [ :updated_asc,   'Last Modified (Oldest First)',   "updated_at ASC"  ],    
    [ :title_asc,     'Title (a..z)',                   "title ASC"       ],   
    [ :title_desc,    'Title (z..a)',                   "title DESC"      ],    
 ]

 SORT_FIELD_OPTIONS = SORT_FIELDS.map { |i| [i[1], i[0]] }    
 SORT_SQL_BY_KEY = Hash[*SORT_FIELDS.map { |i| [i[0], i[2]] }.flatten]

 # Solution folder visiblity constants moved to here

 VISIBILITY = [
  [ :anyone,       I18n.t("solutions.visibility.all"),          1 ], 
  [ :logged_users, I18n.t("solutions.visibility.logged_in_users"), 2 ],
  [ :agents,       I18n.t("solutions.visibility.agents"),          3 ],
  [ :company_users ,I18n.t("solutions.visibility.select_company") , 4]
  ]
  
  VISIBILITY_OPTIONS = VISIBILITY.map { |i| [i[1], i[2]] }
  VISIBILITY_NAMES_BY_KEY = Hash[*VISIBILITY.map { |i| [i[2], i[1]] }.flatten] 
  VISIBILITY_KEYS_BY_TOKEN = Hash[*VISIBILITY.map { |i| [i[0], i[2]] }.flatten] 

  API_OPTIONS = {
    :except  =>  [:account_id, :import_id],
    :include =>  {:tags => { :only => [:name] },
                  :folder => { :except => [:account_id,:import_id],
                               :include => { :customer_folders => { :only => [:customer_id] } }
                          }
                  }
  }

  HUMANIZE_STATS = {
    :thousand => "K+", 
    :million => "M+", 
    :billion => "B+",
    :trillion => "T+",
    :quadrillion => "Q+"
  }

end