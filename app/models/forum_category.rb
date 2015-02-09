class ForumCategory < ActiveRecord::Base
  self.primary_key = :id
  validates_presence_of :name,:account_id
  validates_uniqueness_of :name, :scope => :account_id, :case_sensitive => false


  def self.company_specific?(user)
    (user && user.has_company?)
  end

  def self.user_forums_condition
    condition = "forum_categories.forum_visibility not in (#{Forum::VISIBILITY_KEYS_BY_TOKEN[:agents]},#{Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users]})"
    condition += " OR ( forum_visibility =#{Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users]} AND customer_forums.customer_id = #{User.current.company.id})" if company_specific?(User.current)
    condition
  end

  has_many :forums, :dependent => :destroy, :order => "position"
  has_many :customer_forums , :class_name => "CustomerForum", :through => :forums
  has_many :portal_forums, :class_name => 'Forum', :conditions =>{:forum_visibility => Forum::VISIBILITY_KEYS_BY_TOKEN[:anyone]} , :order => "position"
  has_many :customer_editable_forums,  :class_name => "Forum", :conditions => ['forum_visibility = ? AND forum_type != ?', Forum::VISIBILITY_KEYS_BY_TOKEN[:anyone], Forum::TYPE_KEYS_BY_TOKEN[:announce]], :order => "position"
  has_many :user_forums, :class_name => 'Forum',:conditions => ['forum_visibility != ?', Forum::VISIBILITY_KEYS_BY_TOKEN[:agents]] , :order => "position"
  has_many :portal_topics, :through => :portal_forums
  has_many :user_topics, :through => :user_forums
  has_many :topics , :through => :forums

  has_many :portal_forum_categories,
    :dependent => :delete_all

  has_many :portals, :through => :portal_forum_categories

  has_many :activities,
    :class_name => 'Helpdesk::Activity',
    :as => 'notable'

  # Why have we added position and portal_ids as attr_accessible???
  attr_accessible :name,:description , :import_id, :position, :portal_ids
  
  belongs_to :account

  acts_as_list :scope => :account

  after_create :assign_portal, :set_activity_new_and_clear_cache

  def set_activity_new_and_clear_cache
    create_activity('new_forum_category')
    account.clear_forum_categories_from_cache
  end
  
  
  def add_activity
    create_activity('delete_forum_category')
  end

  def clear_forum_cat_cache
    account.clear_forum_categories_from_cache
  end

  def clear_cache_with_condition
    account.clear_forum_categories_from_cache if (self.changes.key?("name") or self.changes.key?("position"))
  end

  # retrieves forums ordered by position
  def self.find_ordered(account, options = {})
    find :all, options.update(:conditions => {:account_id => account}, :order => 'name')
  end

  def self.forum_names(account)
    account.forum_categories.map { |category|
      [ category.name, category.user_forums.map {|forum| [forum.id, forum.name] } ]
    }
  end


  def to_xml(options = {})
    options[:indent] ||= 2
    xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
    xml.instruct! unless options[:skip_instruct]
    super(:builder => xml, :skip_instruct => true,:include => options[:include],:except => [:account_id,:import_id])
  end

  def as_json (options = {})
    options[:except]=[:account_id,:import_id]
    super options
  end

  def to_liquid
    @forum_categoru_drop ||= Forum::CategoryDrop.new self
  end

  def to_s
    name
  end

  def create_activity(type)
    activities.create(
      :description => "activities.forums.#{type}.long",
      :short_descr => "activities.forums.#{type}.short",
      :account => account,
      :user => User.current,
      :activity_data => {
                          :path => Rails.application.routes.url_helpers.discussion_path(id),
                          :url_params => {
                                           :category_id => id,
                                           :path_generator => 'category_path'
                                          },
                          :title => to_s
                        }
    )
  end

  def assign_portal
    portal_forum_category = self.portal_forum_categories.build
    portal_forum_category.portal_id = account.main_portal.id
    portal_forum_category.save
  end

  def main_portal
    self.portal_forum_categories.main_portal_category.first
  end

end
