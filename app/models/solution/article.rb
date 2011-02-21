class Solution::Article < ActiveRecord::Base
   
   belongs_to :folder, :class_name => 'Solution::Folder'
   
   set_table_name "solution_articles"   
   belongs_to :user, :class_name => 'User'
   
   has_many :attachments,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent => :destroy
    
    attr_protected :attachments
    
  has_many :tag_uses,
    :as => :taggable,
    :class_name => 'Helpdesk::TagUse',
    :dependent => :destroy

  has_many :tags, 
    :class_name => 'Helpdesk::Tag',
    :through => :tag_uses
    
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
    [ :workaround,   "Workaround",   1 ], 
    [ :permanent,    "Permanent",    2 ]
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
  
  def self.search(scope, field, value)

    return scope unless (field && value)

    loose_match = ["#{field} like ?", "%#{value}%"]

    conditions = case field.to_sym
      when :title : loose_match
      when :description  : loose_match
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
