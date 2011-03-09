class Solution::Article < ActiveRecord::Base
  set_table_name "solution_articles"
  
  belongs_to :folder, :class_name => 'Solution::Folder'
  belongs_to :user, :class_name => 'User'
  belongs_to :account
  
  has_many :attachments,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent => :destroy
  has_many :activities,
    :class_name => 'Helpdesk::Activity',
    :as => 'notable',
    :dependent => :destroy
  has_many :tag_uses,
    :as => :taggable,
    :class_name => 'Helpdesk::TagUse',
    :dependent => :destroy
  has_many :tags, 
    :class_name => 'Helpdesk::Tag',
    :through => :tag_uses

 named_scope :visible, :conditions => ['is_public = ?', true] 

  define_index do
    indexes :title, :sortable => true
    indexes description

    has account_id, user_id, created_at, updated_at, is_public
    has '0', :as => :deleted, :type => :boolean

    set_property :delta => :delayed
  end
     
  after_create :create_activity
  attr_accessible :title,:description,:status,:status,:art_type,:is_public
  
  validates_presence_of :title, :description, :user_id , :account_id
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
            [ :permanent,    "Permanent",    1 ],
            [ :workaround,   "Workaround",   2 ]
          ]

  TYPE_OPTIONS = TYPES.map { |i| [i[1], i[2]] }
  TYPE_NAMES_BY_KEY = Hash[*TYPES.map { |i| [i[2], i[1]] }.flatten]
  TYPE_KEYS_BY_TOKEN = Hash[*TYPES.map { |i| [i[0], i[2]] }.flatten]
    
  def type_name
    TYPE_NAMES_BY_KEY[art_type]
  end
  
  def status_name
    STATUS_NAMES_BY_KEY[status]
  end
  
  def to_param
    id ? "#{id}-#{title.downcase.gsub(/[^a-z0-9]+/i, '-')}" : nil
  end

  def nickname
    title
  end
  
  def to_s
    nickname
  end
  
  def self.suggest_solutions(ticket)
    search(ticket.subject, :with => { :account_id => ticket.account.id }, :match_mode => :any)
  end
  
  private
    def create_activity
      activities.create(
        :description => "{{user_path}} created a new solution {{notable_path}}",
        :short_descr => "{{user_path}} created the new solution",
        :account => account,
        :user => user,
        :activity_data => {}
      )
    end
    
end
