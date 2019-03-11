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
  [ :anyone,        "solutions.visibility.all_users",       1 ], 
  [ :logged_users,  "solutions.visibility.logged_in_users", 2 ],
  [ :agents,        "solutions.visibility.agents",          3 ],
  [ :company_users, "solutions.visibility.select_company",  4 ],
  [ :bot,           "solutions.visibility.bot",             5 ]
  ]
  
  VISIBILITY_OPTIONS = VISIBILITY.map { |i| [i[1], i[2]] }
  VISIBILITY_NAMES_BY_KEY = Hash[*VISIBILITY.map { |i| [i[2], i[1]] }.flatten] 
  VISIBILITY_KEYS_BY_TOKEN = Hash[*VISIBILITY.map { |i| [i[0], i[2]] }.flatten] 

  ARTICLE_ORDER_TYPE = [
    [:custom, 'solution_article_meta.position', 1],
    [:title_asc, 'solution_articles.title ASC', 2],
    [:created_desc, 'solution_articles.created_at DESC', 3],
    [:created_asc, 'solution_articles.created_at ASC', 4],
    [:updated_desc, 'solution_articles.updated_at DESC', 5]
  ].freeze

  ARTICLE_ORDER_COLUMN_BY_TYPE = Hash[*ARTICLE_ORDER_TYPE.map { |i| [i[2], i[1]] }.flatten]

  BOT_VISIBILITIES = [VISIBILITY_KEYS_BY_TOKEN[:anyone], VISIBILITY_KEYS_BY_TOKEN[:bot]].freeze

  API_OPTIONS = {
    :except  =>  [
								    :account_id, :import_id, :available, :draft_present, :published, 
										:outdated, :solution_article_id, :language_id, :parent_id, :bool_01, 
										:datetime_01, :delta, :int_01, :int_02, :int_03, :string_01, :string_02
								  ],
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

  COMPANIES_LIMIT = 250

  CONTENT_ALPHA_NUMERIC_REGEX = "[^0-9|S|I|l|O|B|b|q]"

  def self.translated_visibility_option
    VISIBILITY.map { |i| [I18n.t(i[1]), i[2]] }
  end

  def translated_visibility_name_by_key
    Hash[*VISIBILITY.map { |i| [i[2], I18n.t(i[1])] }.flatten]
  end
end