class Forum < ActiveRecord::Base
  self.primary_key = :id
  has_many :activities,
    :class_name => 'Helpdesk::Activity',
    :as => 'notable'

  has_many :monitorships, :as => :monitorable, :class_name => "Monitorship", :dependent => :destroy
  has_many :monitors, :through => :monitorships, :source => :user,
           :conditions => ["#{Monitorship.table_name}.active = ?", true], 
           :order => "#{Monitorship.table_name}.id DESC"
           
  belongs_to_account

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
    [ :anyone ,       I18n.t("forum.visibility.all"),       1 ],
    [ :logged_users, I18n.t("forum.visibility.logged_users"), 2 ],
    [ :agents,       I18n.t("forum.visibility.agents"),       3 ],
    [ :company_users , I18n.t("forum.visibility.select_company") , 4]
  ]

  VISIBILITY_OPTIONS = VISIBILITY.map { |i| [i[1], i[2]] }
  VISIBILITY_NAMES_BY_KEY = Hash[*VISIBILITY.map { |i| [i[2], i[1]] }.flatten]
  VISIBILITY_KEYS_BY_TOKEN = Hash[*VISIBILITY.map { |i| [i[0], i[2]] }.flatten]

   def self.visibility_array(user)
    vis_arr = Array.new
    if user && user.privilege?(:manage_tickets)
      vis_arr = VISIBILITY_NAMES_BY_KEY.keys
    elsif user
      vis_arr = [VISIBILITY_KEYS_BY_TOKEN[:anyone],VISIBILITY_KEYS_BY_TOKEN[:logged_users]]
    else
      vis_arr = [VISIBILITY_KEYS_BY_TOKEN[:anyone]]
    end
  end

  scope :visible, lambda {|user| {
                    # :joins => "LEFT JOIN `customer_forums` ON customer_forums.forum_id = forums.id
                    #             and customer_forums.account_id = forums.account_id ",
                    :conditions => visiblity_condition(user) } }


  scope :in_categories, lambda {|category_ids|
    {
      :conditions => {
        :forum_category_id => category_ids
      }
    }
  }
  def self.visiblity_condition(user)
    condition = "forums.forum_visibility IN (#{self.visibility_array(user).join(",")})"
    condition +=  " OR ( forum_visibility = #{Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users]}
                    AND forums.id IN (SELECT customer_forums.forum_id from customer_forums
                                      where customer_forums.customer_id = #{user.customer_id} and
                                      customer_forums.account_id = #{user.account_id}))"  if (user && user.has_company?)
                # customer_forums.customer_id = #{user.customer_id} )"  if (user && user.has_company?)
    condition
  end

  validates_presence_of :name,:forum_category,:forum_type
  validates_inclusion_of :forum_visibility, :in => VISIBILITY_KEYS_BY_TOKEN.values.min..VISIBILITY_KEYS_BY_TOKEN.values.max
  validates_inclusion_of :forum_type, :in => TYPE_KEYS_BY_TOKEN.values.min..TYPE_KEYS_BY_TOKEN.values.max

  validates_uniqueness_of :name, :scope => :forum_category_id, :case_sensitive => false

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
  has_many :recent_topics, :class_name => 'Topic', :order => 'sticky desc, replied_at DESC'
  has_one  :recent_topic,  :class_name => 'Topic', :order => 'replied_at DESC'
  has_many :posts,     :order => "#{Post.table_name}.created_at DESC", :dependent => :delete_all
  has_one  :recent_post, :order => "#{Post.table_name}.created_at DESC", :class_name => 'Post'
  has_many :customer_forums , :class_name => 'CustomerForum' , :dependent => :destroy

  format_attribute :description
  
  attr_accessible :name, :description, :topics_count, :posts_count, :description_html, 
    :forum_type, :import_id, :forum_visibility, :customer_forums_attributes, :position
  acts_as_list :scope => :forum_category
  
  xss_sanitize :only=>[:description_html], :html_sanitize => [:description_html]

  # after_save :set_topic_delta_flag
  before_update :clear_customer_forums, :backup_forum_changes
  after_commit :update_search_index, on: :update, :if => :forum_visibility_updated?
  after_commit :remove_topics_from_es, on: :destroy
  
  after_create :add_activity_new_and_clear_cache
  after_update :clear_cache_with_condition
  before_destroy :add_activity
  after_destroy :clear_cat_cache

  def add_activity_new_and_clear_cache
    create_activity('new_forum')
    account.clear_forum_categories_from_cache
  end
  
  
  def add_activity
    create_activity('delete_forum')
  end

  def clear_cat_cache
    account.clear_forum_categories_from_cache
  end

  def clear_cache_with_condition
    account.clear_forum_categories_from_cache unless (self.changes.keys & ['name', 'forum_category_id', 'position']).empty?
  end
  #validates_inclusion_of :forum_visibility, :in => VISIBILITY_KEYS_BY_TOKEN.values.min..VISIBILITY_KEYS_BY_TOKEN.values.max


  def customer_forums_attributes=(cust_attr)
    customer_forums.destroy_all
    cust_attr[:customer_id].each do |cust_id|
      customer_forums.build({:customer_id =>cust_id})
    end
  end

  def clear_customer_forums
    customer_forums.destroy_all if (forum_visibility_changed? and
      forum_visibility_was == VISIBILITY_KEYS_BY_TOKEN[:company_users])
  end


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

  def problems?
    self.forum_type == TYPE_KEYS_BY_TOKEN[:problem]
  end

  def stamps?
    ideas? or questions? or problems?
  end

  def stamp_filter
    filter_arr = []
    filter_arr << {"id" => "-", "text" => I18n.t('topic.filter_-')} if ideas?
    Topic::ALL_TOKENS_FOR_FILTER[forum_type].each do |k,v|
      filter_arr << { "id" => k, "text" => v }
    end
    filter_arr
  end

  # retrieves forums ordered by position
  def self.find_ordered(account, options = {})
    find :all, options.update(:conditions => {:account_id => account}, :order => 'position')
  end

  def self.forum_names(account)
    forums = account.user_forums
    forums.map{|forum| [forum.id, forum.name]}
  end

  def type_name
    TYPE_NAMES_BY_KEY[forum_type]
  end

  def type_symbol
    TYPE_SYMBOL_BY_KEY[forum_type].to_s
  end

  def visible?(user)
    return true if (user and user.agent?)
    return true if self.forum_visibility == VISIBILITY_KEYS_BY_TOKEN[:anyone]
    return true if (user and (self.forum_visibility == VISIBILITY_KEYS_BY_TOKEN[:logged_users]))
    return true if (user && (self.forum_visibility == VISIBILITY_KEYS_BY_TOKEN[:company_users]) && 
      user.company  && customer_forums.map(&:customer_id).include?(user.company.id))
  end

  # def set_topic_delta_flag
  #   self.topics.each do |topic|
  #     topic.delta = true
  #     topic.save
  #   end
  # end

  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:include => options[:include],:except => [:account_id,:import_id])
  end

  def as_json(options={})
    options[:except] = [:account_id,:import_id]
    super options
  end

  def visible_to_all?
    forum_visibility == VISIBILITY_KEYS_BY_TOKEN[:anyone]
  end

  def visibility_name
    VISIBILITY_NAMES_BY_KEY[forum_visibility]
  end

  def to_liquid
    @forum_forum_drop ||= Forum::ForumDrop.new self
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
                          :path => Rails.application.routes.url_helpers.discussions_forum_path(id),
                          'category_name' => h(forum_category.to_s),
                          :url_params => {
                                           :id => id,
                                           :path_generator => 'discussions_forum_path'
                                          },
                          :title => h(to_s),
                          :version => 2
                        }
    )
  end

  def update_search_index
    SearchSidekiq::IndexUpdate::ForumTopics.perform_async({ :forum_id => id }) if ES_ENABLED
    
    SearchV2::TopicOperations::UpdateForum.perform_async({ :forum_id => id }) if Account.current.features_included?(:es_v2_writes)
  end

  def remove_topics_from_es
    SearchSidekiq::RemoveFromIndex::ForumTopics.perform_async({ :deleted_topics => @deleted_topic_ids }) if ES_ENABLED
    
    SearchV2::TopicOperations::RemoveForumTopics.perform_async({ :forum_id => id }) if Account.current.features_included?(:es_v2_writes)
  end

  def backup_forum_topic_ids
    @deleted_topic_ids = self.topics.map(&:id)
  end

  def unsubscribed_agents
    user_ids = monitors.map(&:id)
    account.agents_from_cache.reject{ |a| user_ids.include? a.user_id }
  end

  private

    def backup_forum_changes
      @all_changes = self.changes.clone
    end

    def forum_visibility_updated?
      @all_changes.has_key?(:forum_visibility)
    end

end
