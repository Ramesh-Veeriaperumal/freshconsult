module Solution::Constants
	
	STATUSES = [
    [ :draft,     I18n.t("solutions.status.draft"),        1 ], 
    [ :published, I18n.t("solutions.status.published"),    2 ]
  ]

  STATUS_OPTIONS = STATUSES.map { |i| [i[1], i[2]] }
  STATUS_NAMES_BY_KEY = Hash[*STATUSES.map { |i| [i[2], i[1]] }.flatten]
  STATUS_KEYS_BY_TOKEN = Hash[*STATUSES.map { |i| [i[0], i[2]] }.flatten]
  
  TYPES = [
    [ :permanent,  I18n.t("solutions.types.permanent"),   1 ],
    [ :workaround, I18n.t("solutions.types.workaround"),  2 ]
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
end