# encoding: utf-8
class Helpdesk::Tag < ActiveRecord::Base
  
  self.primary_key = :id
  include Cache::Memcache::Helpdesk::Tag
  include Search::ElasticSearchIndex

  after_commit :clear_cache

  self.table_name =  "helpdesk_tags"
  
  belongs_to_account

  has_many :tag_uses,
    :class_name => 'Helpdesk::TagUse',
    :dependent => :delete_all

  has_many :tickets,
    :class_name => 'Helpdesk::Ticket',
    :source => :taggable,
    :source_type => "Helpdesk::Ticket",
    :through => :tag_uses

  has_many :users,
    :class_name => 'User',
    :source => :taggable,
    :source_type => "User",
    :through => :tag_uses

  has_many :contacts,
    :class_name => 'User',
    :source => :taggable,
    :source_type => "User",
    :through => :tag_uses,
    :conditions => { :helpdesk_agent => false, :deleted => false }

  has_many :solution_articles,
           :class_name => 'Solution::Article',
           :source => :taggable,
           :source_type => "Solution::Article",
           :through => :tag_uses

  scope :with_taggable_type, lambda { |taggable_type| {
            :include => :tag_uses,
            :conditions => ["helpdesk_tag_uses.taggable_type = ?", taggable_type] }
        }
  scope :most_used, lambda { |num| { :limit => num, :order => 'tag_uses_count DESC'}
        }

  scope :sort_tags, lambda  { |sort_type| { :order => SORT_SQL_BY_KEY[(sort_type).to_sym] || SORT_SQL_BY_KEY[:activity_desc] }  }

  scope :tag_search, lambda { |keyword| { :conditions => ["name like ?","#{keyword}%"] } if keyword.present? }





  SORT_FIELDS = [
    [ :activity_desc, 'Most Used',    "tag_uses_count DESC"  ],
    [ :activity_asc,  'Least Used',   "tag_uses_count ASC"  ],
    [ :name_asc,      'Name (a..z)',  "name ASC"  ],
    [ :name_desc,     'Name (z..a)',  "name DESC"  ]
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
  
  def to_liquid
    @helpdesk_tag_drop ||= (Helpdesk::TagDrop.new self)
  end

  def ticket_count
    tickets.visible.size
  end

  def to_indexed_json
    as_json({
            :root => "helpdesk/tag",
            :tailored_json => true,
            :only => [ :name, :tag_uses_count, :account_id ]
            }).to_json
  end
end
