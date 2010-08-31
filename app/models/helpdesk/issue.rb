class Helpdesk::Issue < ActiveRecord::Base
  set_table_name "helpdesk_issues"

  belongs_to :user,
    :class_name => 'User'

  belongs_to :owner,
    :class_name => 'User'

  has_many :ticket_issues,
    :class_name => 'Helpdesk::TicketIssue',
    :dependent => :destroy

  has_many :tickets, 
    :class_name => 'Helpdesk::Ticket',
    :through => :ticket_issues

  has_many :notes, 
    :class_name => 'Helpdesk::Note',
    :as => 'notable',
    :dependent => :destroy

  named_scope :newest, lambda { |num| { :limit => num, :order => 'created_at DESC' } }
  named_scope :visible, :conditions => "status > 0" 

  STATUSES = [
    [ :open,        "OPEN",                           1 ], 
    [ :solved,      "CLOSED: Problem Solved",         0 ], 
    [ :not_fixable, "CLOSED: Not Fixable",           -1 ], 
    [ :bug,         "CLOSED: Moved to Bug Tracker",  -3 ]
  ]

  STATUS_OPTIONS = STATUSES.map { |i| [i[1], i[2]] }
  STATUS_NAMES_BY_KEY = Hash[*STATUSES.map { |i| [i[2], i[1]] }.flatten]
  STATUS_KEYS_BY_TOKEN = Hash[*STATUSES.map { |i| [i[0], i[2]] }.flatten]

  SEARCH_FIELDS = [
    [ :title,         'Title'        ],
    [ :description,   'Description'  ]
  ]

  SEARCH_FIELD_OPTIONS = SEARCH_FIELDS.map { |i| [i[1], i[0]] }

  SORT_FIELDS = [
    [ :created_asc,   'Date Created (Oldest First)',    "created_at ASC"  ],
    [ :created_desc,  'Date Created (Newest First)',    "created_at DESC"  ],
    [ :updated_asc,   'Last Modified (Oldest First)',   "updated_at ASC"  ],
    [ :updated_desc,  'Last Modified (Newest First)',   "updated_at DESC"  ],
    [ :status,        'Status',                         "status DESC"  ],
  ]

  SORT_FIELD_OPTIONS = SORT_FIELDS.map { |i| [i[1], i[0]] }
  SORT_SQL_BY_KEY = Hash[*SORT_FIELDS.map { |i| [i[0], i[2]] }.flatten]

  validates_presence_of :title, :description, :status
  validates_numericality_of :status, :user_id, :only_integer => true
  validates_inclusion_of :status, :in => STATUS_KEYS_BY_TOKEN.values.min..STATUS_KEYS_BY_TOKEN.values.max

  def to_param 
    id ? "#{id}-#{title.downcase.gsub(/[^a-z0-9]+/i, '-')}" : nil
  end 

  def status=(val)
    self[:status] = STATUS_KEYS_BY_TOKEN[val] || val
  end

  def status_name
    STATUS_NAMES_BY_KEY[status]
  end

  def create_status_note(message, user = nil)
    notes.create(
      :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['status'],
      :user => user,
      :body => message
    )
  end

  def source=(val)
    self[:source] = SOURCE_KEYS_BY_TOKEN[val] || val
  end

  def source_name
    SOURCE_NAMES_BY_KEY[source]
  end

  def self.filter(filters, user = nil, scope = nil)

    conditions = {
      :all          =>    "",
      :open         =>    "status > 0",
      :unassigned   =>    {:owner_id => nil, :deleted => false},
      :deleted      =>    {:deleted => true},
      :visible      =>    {:deleted => false},
      :responded_by =>    {:owner_id => (user && user.id) || -1, :deleted => false},
      :monitored_by =>    {} # See below
    }

    filters.inject(scope || self) do |scope, f|
      f = f.to_sym

      if user && f == :monitored_by
        user.subscribed_tickets.scoped(:conditions => {:deleted => false})
      else
        scope.scoped(:conditions => conditions[f])
      end
    end

  end

  def self.search(scope, field, value)

    return scope unless (field && value)

    loose_match = ["#{field} like ?", "%#{value}%"]
    exact_match = {field => value}

    conditions = case field.to_sym
      when :title        :  loose_match
      when :description  :  loose_match
    end

    # Protect us from SQL injection in the 'field' param
    return scope unless conditions

    scope.scoped(:conditions => conditions)
  end

  def nickname
    title
  end

  def freshness
    return :new if !owner
    return :closed if status <= 0
    return :open
  end

end
