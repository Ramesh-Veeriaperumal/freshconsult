require 'digest/md5'

class Helpdesk::Ticket < ActiveRecord::Base
  set_table_name "helpdesk_tickets"

  before_validation_on_create :set_tokens
  before_create :set_spam

  belongs_to :responder,
    :class_name => 'User'

  belongs_to :requester,
    :class_name => 'User'

  has_many :notes, 
    :class_name => 'Helpdesk::Note',
    :as => 'notable',
    :dependent => :destroy

  has_many :reminders, 
    :class_name => 'Helpdesk::Reminder',
    :dependent => :destroy

  has_many :subscriptions, 
    :class_name => 'Helpdesk::Subscription',
    :dependent => :destroy

  has_many :tag_uses,
    :class_name => 'Helpdesk::TagUse',
    :dependent => :destroy

  has_many :tags, 
    :class_name => 'Helpdesk::Tag',
    :through => :tag_uses

  has_many :ticket_issues,
    :class_name => 'Helpdesk::TicketIssue',
    :dependent => :destroy

  has_many :issues, 
    :class_name => 'Helpdesk::Issue',
    :through => :ticket_issues



  named_scope :newest, lambda { |num| { :limit => num, :order => 'created_at DESC' } }
  named_scope :visible, :conditions => ["spam=? AND deleted=? AND status > 0", false, false] 

  SOURCES = [
    [ :staff,     "Staff Initiated",      0 ],
    [ :email,     "Email",                1 ],
    [ :web_form,  "Web Form",             2 ],
    [ :phone,     "Phone",                3 ],
    [ :in_person, "In Person",            4 ],
    [ :mail,      "Mail",                 5 ],
    [ :other,     "Other",                6 ],
    [ :forum,     "Forum",                7 ],
    [ :im,        "Instant Messenger",    8 ],
    [ :fax,       "Fax",                  9 ],
    [ :voicemail, "Voicemail",            10],
  ]

  SOURCE_OPTIONS = SOURCES.map { |i| [i[1], i[2]] }
  SOURCE_NAMES_BY_KEY = Hash[*SOURCES.map { |i| [i[2], i[1]] }.flatten]
  SOURCE_KEYS_BY_TOKEN = Hash[*SOURCES.map { |i| [i[0], i[2]] }.flatten]

  STATUSES = [
    [ :open,        "OPEN",                           1 ], 
    [ :waiting,     "OPEN: Waiting",                  2 ], 
    [ :solved,      "CLOSED: Problem Solved",         0 ], 
    [ :not_fixable, "CLOSED: Not Fixable",           -1 ], 
    [ :unreachable, "CLOSED: Customer Unreachable",  -2 ], 
    [ :bug,         "CLOSED: Moved to Bug Tracker",  -3 ]
  ]

  STATUS_OPTIONS = STATUSES.map { |i| [i[1], i[2]] }
  STATUS_NAMES_BY_KEY = Hash[*STATUSES.map { |i| [i[2], i[1]] }.flatten]
  STATUS_KEYS_BY_TOKEN = Hash[*STATUSES.map { |i| [i[0], i[2]] }.flatten]

  SEARCH_FIELDS = [
    [ :name,          'Name'                ],
    [ :phone,         'Phone'               ],
    [ :email,         'Email Address'       ],
    [ :description,   'Ticket Description'  ],
    [ :source,        'Source of Ticket'    ]
  ]

  SEARCH_FIELD_OPTIONS = SEARCH_FIELDS.map { |i| [i[1], i[0]] }

  SORT_FIELDS = [
    [ :created_asc,   'Date Created (Oldest First)',    "created_at ASC"  ],
    [ :created_desc,  'Date Created (Newest First)',    "created_at DESC"  ],
    [ :updated_asc,   'Last Modified (Oldest First)',   "updated_at ASC"  ],
    [ :updated_desc,  'Last Modified (Newest First)',   "updated_at DESC"  ],
    [ :status,        'Status',                         "status DESC"  ],
    [ :source,        'Source',                         "source DESC"  ]
  ]

  SORT_FIELD_OPTIONS = SORT_FIELDS.map { |i| [i[1], i[0]] }
  SORT_SQL_BY_KEY = Hash[*SORT_FIELDS.map { |i| [i[0], i[2]] }.flatten]

  validates_presence_of :name, :source, :id_token, :access_token, :status, :source
  validates_uniqueness_of :id_token
  validates_length_of :email, :in => 5..320, :allow_nil => false, :allow_blank => false
  validates_numericality_of :source, :status, :only_integer => true
  validates_numericality_of :requester_id, :responder_id, :only_integer => true, :allow_nil => true
  validates_inclusion_of :source, :in => 0..SOURCES.size-1
  validates_inclusion_of :status, :in => STATUS_KEYS_BY_TOKEN.values.min..STATUS_KEYS_BY_TOKEN.values.max
  validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, :allow_nil => false, :allow_blank => false

  def to_param 
    id_token 
  end 

  def self.find_by_param(token)
    find_by_id_token(token)
  end

  def freshness
    return :new if !responder
    return :closed if status <= 0

    last_note = notes.find_by_private(false, :order => "created_at DESC")

    (last_note && last_note.incoming) ? :reply : :waiting
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
      :unassigned   =>    {:responder_id => nil, :deleted => false, :spam => false},
      :spam         =>    {:spam => true},
      :deleted      =>    {:deleted => true},
      :visible      =>    {:deleted => false, :spam => false},
      :responded_by =>    {:responder_id => (user && user.id) || -1, :deleted => false, :spam => false},
      :monitored_by =>    {} # See below
    }

    filters.inject(scope || self) do |scope, f|
      f = f.to_sym

      if user && f == :monitored_by
        user.subscribed_tickets.scoped(:conditions => {:spam => false, :deleted => false})
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
      when :name         :  loose_match
      when :phone        :  loose_match
      when :email        :  loose_match
      when :description  :  loose_match
      when :status       :  exact_match
      when :urgent       :  exact_match
      when :source       :  exact_match
    end

    # Protect us from SQL injection in the 'field' param
    return scope unless conditions

    scope.scoped(:conditions => conditions)
  end

  def nickname
    name
  end

  def encode_id_token
    "[#{id_token}]"
  end

  def train(category)
    classifier.untrain(spam ? :spam : :ham, spam_text) if trained
    classifier.train(category, spam_text)
    classifier.save
    self[:trained] = true
    self[:spam] = (category == :spam)
  end
    
  def self.extract_id_token(text)
    pieces = text.match(/\[([a-z0-9]{32})\]/)
    pieces && pieces[1]
  end

  def classifier
    @classifier ||= Helpdesk::Classifier.find_by_name("spam")
  end

  def set_spam
    self[:spam] ||= (classifier.category?(spam_text) == "Spam") if spam_text && !Helpdesk::SPAM_TRAINING_MODE
    true
  end

  def spam_text
    @spam_text ||= notes.empty? ? description : notes.find(:first).body
  end

  def set_tokens
    self.id_token ||= make_token(Helpdesk::SECRET_1)
    self.access_token ||= make_token(Helpdesk::SECRET_2)
  end

  def make_token(secret)
    Digest::MD5.hexdigest(secret + Time.now.to_f.to_s).downcase
  end

end
