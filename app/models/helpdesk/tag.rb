class Helpdesk::Tag < ActiveRecord::Base
  set_table_name "helpdesk_tags"
  
  belongs_to :account

  has_many :tag_uses,
    :class_name => 'Helpdesk::TagUse',
    :dependent => :destroy

  has_many :tickets,
    :class_name => 'Helpdesk::Ticket',
    :source => :taggable,
    :source_type => "Helpdesk::Ticket",
    :through => :tag_uses

  has_many :users,
    :class_name => 'User',
    :source => :taggable,
    :source_type => "User",
    :conditions => 'users.account_id = #{account_id}',
    :through => :tag_uses

  has_many :contacts,
    :class_name => 'User',
    :source => :taggable,
    :source_type => "User",
    :through => :tag_uses,
    :conditions =>{:user_role =>[User::USER_ROLES_KEYS_BY_TOKEN[:customer], User::USER_ROLES_KEYS_BY_TOKEN[:client_manager]] , :deleted =>false}

  named_scope :with_taggable_type, lambda { |taggable_type| { 
            :include => :tag_uses,
            :conditions => ["helpdesk_tag_uses.taggable_type = ?", taggable_type] }
        }

  SORT_FIELDS = [
    [ :activity_desc, 'Most Used',    "tag_uses_count DESC"  ],
    [ :activity_asc,  'Least Used',   "tag_uses_count ASC"  ],
    [ :name_asc,      'Name (a..z)',  "name ASC"  ],
    [ :name_desc,     'Name (z..a)',  "name DESC"  ],
  ]

  SORT_FIELD_OPTIONS = SORT_FIELDS.map { |i| [i[1], i[0]] }
  SORT_SQL_BY_KEY = Hash[*SORT_FIELDS.map { |i| [i[0], i[2]] }.flatten]

  validates_presence_of :name
  validates_length_of :name, :in => (1..32)
  
  def nickname
    name
  end

  def uses_count
    self.tag_uses_count.blank? ? 0: self.tag_uses_count
  end

  def tag_size(biggest = 1)
    min = -20
    max = 50

    font_size = 100
    font_size += (self.uses_count / biggest * (max-min) ) + min if biggest > 1 and self.uses_count > 0
    
    font_size
  end

  def to_param
    id ? "#{id}-#{name.downcase.gsub(/[^a-z0-9]+/i, '-')}" : nil
  end

  def to_s
    return name
  end
end
