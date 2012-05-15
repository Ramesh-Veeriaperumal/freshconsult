class Solution::Article < ActiveRecord::Base
  set_table_name "solution_articles"
  
  acts_as_list :scope => :folder

  belongs_to :folder, :class_name => 'Solution::Folder'
  belongs_to :user, :class_name => 'User'
  belongs_to :account
  
  before_save :set_un_html_content
  
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

 

  define_index do
    indexes :title, :sortable => true
    indexes :desc_un_html, :as => :description
    indexes tags.name , :as => :tags

    has account_id, user_id, status
    has folder.category_id, :as => :category_id 
    has '0', :as => :deleted, :type => :boolean    
    has folder.visibility , :as => :visibility, :type => :integer

    set_property :delta => :delayed
    set_property :field_weights => {
      :title        => 10,
      :description  => 6
    }
  end

  after_create :create_activity
  attr_protected :account_id ,:attachments
  
  validates_presence_of :title, :description, :user_id , :account_id
  validates_length_of :title, :in => 3..240
  validates_numericality_of :user_id
    
  STATUSES = [
                  [ :draft,       I18n.t("solutions.status.draft"),        1 ], 
                  [ :published,   I18n.t("solutions.status.published"),    2 ]
              ]

  STATUS_OPTIONS = STATUSES.map { |i| [i[1], i[2]] }
  STATUS_NAMES_BY_KEY = Hash[*STATUSES.map { |i| [i[2], i[1]] }.flatten]
  STATUS_KEYS_BY_TOKEN = Hash[*STATUSES.map { |i| [i[0], i[2]] }.flatten]
  
  TYPES = [
            [ :permanent,    I18n.t("solutions.types.permanent"),   1 ],
            [ :workaround,   I18n.t("solutions.types.workaround"),  2 ]
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
 
 named_scope :visible, :conditions => ['status = ?',STATUS_KEYS_BY_TOKEN[:published]] 
    
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
    to_ret = suggest(ticket, ticket.subject)
    to_ret = suggest(ticket, ticket.description) if to_ret.empty?
    
    to_ret
    
  end
  
  def self.suggest(ticket, search_by)
    return [] if search_by.blank? || (search_by = search_by.gsub(/[\^\$]/, '')).blank?
    search(search_by, :with => { :account_id => ticket.account.id }, :match_mode => :any, :per_page => 10)
  end
  
  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:except => [:account_id,:import_id]) 
  end
  
  private    
    def create_activity
      activities.create(
        :description => 'activities.solutions.new_solution.long',
        :short_descr => 'activities.solutions.new_solution.short',
        :account => account,
        :user => user,
        :activity_data => {}
      )
    end
  
    def set_un_html_content        
      self.desc_un_html = (self.description.gsub(/<\/?[^>]*>/, "")).gsub(/&nbsp;/i,"") unless self.description.empty?
    end
    
end
