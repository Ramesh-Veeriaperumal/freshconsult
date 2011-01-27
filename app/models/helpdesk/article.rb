class Helpdesk::Article < ActiveRecord::Base
  set_table_name "helpdesk_articles"

  belongs_to :user,
    :class_name => 'User'
    
  belongs_to :guide , :class_name  =>'Helpdesk::Guide'

  has_many :article_guides,
    :class_name => 'Helpdesk::ArticleGuide',
    :dependent => :destroy

  has_many :guides, 
    :class_name => 'Helpdesk::Guide',
    :through => :article_guides

  has_many :attachments,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent => :destroy



  attr_protected :guides, :attachments

  named_scope :display_order, :include => :article_guides, :order => 'helpdesk_article_guides.position ASC' 
  #named_scope :visible, :include => :guides, :conditions => ['helpdesk_guides.hidden = ?', false] 
  
  named_scope :visible, lambda { |account|
    { :include => :guides,
      :conditions => ["helpdesk_guides.account_id = ? ", account], 
      :order => 'helpdesk_article_guides.position ASC'
    }
  }
  
  named_scope :limit, lambda { |num| num ? { :limit => num } : {} }

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

  SEARCH_FIELDS = [
    [ :title, 'Title' ],
    [ :body,  'Body'  ]
  ]

  SEARCH_FIELD_OPTIONS = SEARCH_FIELDS.map { |i| [i[1], i[0]] }

  validates_presence_of :title, :body, :user_id
  validates_length_of :title, :in => 3..240
  validates_numericality_of :user_id

 STATUSES = [
    [ :draft,       "Draft",        1 ], 
    [ :published,   "Published",    2 ]
  ]

  STATUS_OPTIONS = STATUSES.map { |i| [i[1], i[2]] }
  STATUS_NAMES_BY_KEY = Hash[*STATUSES.map { |i| [i[2], i[1]] }.flatten]
  STATUS_KEYS_BY_TOKEN = Hash[*STATUSES.map { |i| [i[0], i[2]] }.flatten]
  
  TYPES = [
    [ :workaround,   "Workaround",   1 ], 
    [ :permanent,    "Permanent",    2 ]
  ]

  TYPE_OPTIONS = TYPES.map { |i| [i[1], i[2]] }
  TYPE_NAMES_BY_KEY = Hash[*TYPES.map { |i| [i[2], i[1]] }.flatten]
  TYPE_KEYS_BY_TOKEN = Hash[*TYPES.map { |i| [i[0], i[2]] }.flatten]
  
  
  
  
  def self.search(scope, field, value)

    return scope unless (field && value)

    loose_match = ["#{field} like ?", "%#{value}%"]

    conditions = case field.to_sym
      when :title : loose_match
      when :body  : loose_match
    end

    # Protect us from SQL injection in the 'field' param
    return scope unless conditions

    scope.scoped(:conditions => conditions)
  end


  def to_param
    id ? "#{id}-#{title.downcase.gsub(/[^a-z0-9]+/i, '-')}" : nil
  end

  def nickname
    title
  end
  
end
