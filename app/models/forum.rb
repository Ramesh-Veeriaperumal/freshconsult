class Forum < ActiveRecord::Base
  acts_as_list :scope => :forum_category
  
  TYPES = [
    [ :howto,    I18n.t("forum.types.howto"),    1 ],
    [ :ideas,    I18n.t("forum.types.ideas"),    2 ],
    [ :problem,  I18n.t("forum.types.problem"),  3 ],
    [ :announce, I18n.t("forum.types.announce"), 4 ]
  ]

  TYPE_OPTIONS = TYPES.map { |i| [i[1], i[2]] }
  TYPE_NAMES_BY_KEY = Hash[*TYPES.map { |i| [i[2], i[1]] }.flatten] 
  TYPE_KEYS_BY_TOKEN = Hash[*TYPES.map { |i| [i[0], i[2]] }.flatten]
  TYPE_SYMBOL_BY_KEY = Hash[*TYPES.map { |i| [i[2], i[0]] }.flatten]
  
  VISIBILITY = [
    [ :anyone,       I18n.t("forum.visibility.anyone"),       1 ],
    [ :logged_users, I18n.t("forum.visibility.logged_users"), 2 ],
    [ :agents,       I18n.t("forum.visibility.agents"),       3 ]
  ]

  VISIBILITY_OPTIONS = VISIBILITY.map { |i| [i[1], i[2]] }
  VISIBILITY_NAMES_BY_KEY = Hash[*VISIBILITY.map { |i| [i[2], i[1]] }.flatten] 
  VISIBILITY_KEYS_BY_TOKEN = Hash[*VISIBILITY.map { |i| [i[0], i[2]] }.flatten]

  validates_presence_of :name,:forum_category,:forum_type
  validates_inclusion_of :forum_visibility, :in => VISIBILITY_KEYS_BY_TOKEN.values.min..VISIBILITY_KEYS_BY_TOKEN.values.max
  validates_inclusion_of :forum_type, :in => TYPE_KEYS_BY_TOKEN.values.min..TYPE_KEYS_BY_TOKEN.values.max
 
  validates_uniqueness_of :name, :scope => :forum_category_id
  
  belongs_to :forum_category

  has_many :moderatorships, :dependent => :destroy
  has_many :moderators, :through => :moderatorships, :source => :user

  has_many :topics,  :dependent => :delete_all
  has_many :portal_topics, :class_name => 'Topic'
  has_many :user_topics, :class_name => 'Topic'
  #has_many :feature_topics, :class_name => 'Topic',:order => 'votes_count desc', :dependent => :delete_all
  
  has_one  :recent_topic, :class_name => 'Topic', :order => 'sticky desc, replied_at desc'

  # this is used to see if a forum is "fresh"... we can't use topics because it puts
  # stickies first even if they are not the most recently modified
  has_many :recent_topics, :class_name => 'Topic', :order => 'replied_at DESC'
  has_one  :recent_topic,  :class_name => 'Topic', :order => 'replied_at DESC'

  has_many :posts,     :order => "#{Post.table_name}.created_at DESC", :dependent => :delete_all
  has_one  :recent_post, :order => "#{Post.table_name}.created_at DESC", :class_name => 'Post'
  
  format_attribute :description
  
  attr_accessible :name,:description, :description_html, :forum_type ,:import_id, :forum_visibility
  
   after_save :set_topic_delta_flag
  
  #validates_inclusion_of :forum_visibility, :in => VISIBILITY_KEYS_BY_TOKEN.values.min..VISIBILITY_KEYS_BY_TOKEN.values.max
  
  
#  def self.search(scope, field, value)
#    return scope unless (field && value)
#    loose_match = ["#{field} like ?", "%#{value}%"]
#    exact_match = {field => value}
#    conditions = case field.to_sym
#      when :stamp_type      :  exact_match
#    end
#    return scope unless conditions
#    scope.scoped(:conditions => conditions)
#  end
  
  def announcement?()
    forum_type == TYPE_KEYS_BY_TOKEN[:announce]
  end

  def ideas?()
    self.forum_type == TYPE_KEYS_BY_TOKEN[:ideas] 
  end
  
  def questions?()
    self.forum_type == TYPE_KEYS_BY_TOKEN[:howto]
  end
  
  # retrieves forums ordered by position
  def self.find_ordered(account, options = {})
    find :all, options.update(:conditions => {:account_id => account}, :order => 'position')
  end
  
  def type_name
    TYPE_NAMES_BY_KEY[forum_type]
  end

  def type_symbol
    TYPE_SYMBOL_BY_KEY[forum_type].to_s
  end
    
  def visible?(user)
    return true if self.forum_visibility == VISIBILITY_KEYS_BY_TOKEN[:anyone]
    return true if (user and (self.forum_visibility == VISIBILITY_KEYS_BY_TOKEN[:logged_users]))
    return true if (user and user.has_manage_forums? and (self.forum_visibility == VISIBILITY_KEYS_BY_TOKEN[:agents]) )
  end
  
  def set_topic_delta_flag
    self.topics.each do |topic|
      topic.delta = true
      topic.save
    end
  end
  
  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:except => [:account_id,:import_id]) 
  end
   
end
