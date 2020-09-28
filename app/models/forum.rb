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
    [ :howto,    "forum.types.howto",    1,    "Questions"],
    [ :ideas,    "forum.types.ideas",    2,    "Ideas" ],
    [ :problem,  "forum.types.problem",    3,    "Problems" ],
    [ :announce, "forum.types.announce",    4,    "Announcement" ],
  ]

  TYPE_OPTIONS = TYPES.map { |i| [i[1], i[2]] }
  TYPE_NAMES_BY_KEY = Hash[*TYPES.map { |i| [i[2], i[1]] }.flatten]
  TYPE_KEYS_BY_TOKEN = Hash[*TYPES.map { |i| [i[0], i[2]] }.flatten]
  TYPE_SYMBOL_BY_KEY = Hash[*TYPES.map { |i| [i[2], i[0]] }.flatten]
  CLASS_NAME_BY_TYPE = Hash[*TYPES.map { |i| [i[2], i[3]] }.flatten]

  VISIBILITY = [
    [ :anyone ,      "forum.visibility.all",       1 ],
    [ :logged_users, "forum.visibility.logged_users", 2 ],
    [ :agents,       "forum.visibility.agents",       3 ],
    [ :company_users,"forum.visibility.select_company", 4]
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

  scope :visible, -> (user) { where(visiblity_condition(user))}
  scope :in_categories, -> (category_ids) { where(forum_category_id: category_ids)}
  
  def self.visiblity_condition(user)
    condition = "forums.forum_visibility IN (#{self.visibility_array(user).join(",")})"
    condition +=  " OR ( forum_visibility = #{Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users]}
                      AND forums.id IN (SELECT customer_forums.forum_id from customer_forums
                                        where customer_forums.customer_id in (#{user.company_ids_str}) and
                                        customer_forums.account_id = #{user.account_id}))" if (user && user.has_company?)
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

  # this is used to see if a forum is "fresh"... we can't use topics because it puts
  # stickies first even if they are not the most recently modified

  has_many :recent_topics, :class_name => 'Topic', :order => 'sticky desc, replied_at DESC'
  has_one  :recent_topic, :class_name => 'Topic', :order => 'sticky desc, replied_at desc'
  has_many :posts,     :order => "#{Post.table_name}.created_at DESC", :dependent => :delete_all
  has_one  :recent_post, :order => "#{Post.table_name}.created_at DESC", :class_name => 'Post'
  has_many :customer_forums , :class_name => 'CustomerForum' , :dependent => :destroy

  format_attribute :description
  
  attr_accessible :name, :description, :topics_count, :posts_count, :description_html, 
    :forum_type, :import_id, :forum_visibility, :customer_forums_attributes, :position, :convert_to_ticket
  acts_as_list :scope => :forum_category
  
  xss_sanitize :only=>[:description_html], :html_sanitize => [:description_html]

  # after_save :set_topic_delta_flag
  before_update :clear_customer_forums, :backup_forum_changes
  after_commit :update_search_index, on: :update, :if => :forum_visibility_updated?
  after_commit :remove_topics_from_es, on: :destroy
  
  after_create :add_activity_new_and_clear_cache
  after_update :clear_cache_with_condition
  before_destroy :add_activity
  after_destroy :clear_cat_cache, :clear_moderation_records

  include RabbitMq::Publisher

  def self.type_list
    TYPES.map { |i| [I18n.t(i[1]), i[2]] }
  end

  def self.visibility_list
    VISIBILITY.map { |i| [I18n.t(i[1]), i[2]] }
  end

  def self.visibility_keys
    Hash[*VISIBILITY.map { |i| [i[2], I18n.t(i[1])] }.flatten]
  end

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
    Topic.all_tokens_for_filters[forum_type].each do |k,v|
      filter_arr << { "id" => k, "text" => v }
    end
    filter_arr
  end

  # retrieves forums ordered by position
  def self.find_ordered(account, options = {})
    return where(account_id: account).order('position').all.to_a if options.blank?

    Rails.logger.info "forum :: find_ordered :: #{options.inspect}" # PRE-RAILS: Need to update find(:all) once options passed is changeable.
    find :all, options.update(:conditions => {:account_id => account}, :order => 'position')
  end

  def self.forum_names(account)
    forums = account.user_forums
    forums.map{|forum| [forum.id, forum.name]}
  end

  def type_name
    I18n.t(TYPE_NAMES_BY_KEY[forum_type])
  end

  def type_class
    CLASS_NAME_BY_TYPE[forum_type]
  end

  def type_symbol
    TYPE_SYMBOL_BY_KEY[forum_type].to_s
  end

  def visible?(user)
    return true if (user and user.agent?)
    return true if self.forum_visibility == VISIBILITY_KEYS_BY_TOKEN[:anyone]
    return false unless user
    return true if self.forum_visibility == VISIBILITY_KEYS_BY_TOKEN[:logged_users]
    company_cdn = user.contractor? ? (user.company_ids & customer_forums.map(&:customer_id)).any? : 
                    (user.company  && customer_forums.map(&:customer_id).include?(user.company.id))
    return true if ((self.forum_visibility == VISIBILITY_KEYS_BY_TOKEN[:company_users]) && 
      company_cdn)
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
    self.class.visibility_keys[forum_visibility]
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
    SearchSidekiq::IndexUpdate::ForumTopics.perform_async({ :forum_id => id }) if Account.current.esv1_enabled?
    
    SearchV2::IndexOperations::UpdateTopicForum.perform_async({ :forum_id => id })
  end

  def remove_topics_from_es
    SearchSidekiq::RemoveFromIndex::ForumTopics.perform_async({ :deleted_topics => @deleted_topic_ids }) if Account.current.esv1_enabled?
    
    SearchV2::IndexOperations::RemoveForumTopics.perform_async({ :forum_id => id })
  end

  def backup_forum_topic_ids
    @deleted_topic_ids = self.topics.pluck(:id)
  end

  def unsubscribed_agents
    user_ids = monitors.map(&:id)
    Sharding.run_on_slave { account.agents_hash_from_cache.except(*user_ids) }
  end

  def clear_moderation_records
    Community::ClearModerationRecords.perform_async(self.id, self.class.to_s, @deleted_topic_ids)
  end

  private

    def backup_forum_changes
      @all_changes = self.changes.clone
    end

    def forum_visibility_updated?
      @all_changes.has_key?(:forum_visibility)
    end

    def to_rmq_json(keys,action)
      forum_identifiers
      #destroy_action?(action) ? forum_identifiers : return_specific_keys(forum_identifiers, keys)
    end

    def forum_identifiers
      @rmq_forum_identifiers ||= {
      "id"          =>  id,
      "name"        =>  name, 
      "post_count"  => posts_count,
      "forum_category_id" => forum_category_id,
      "forum_type"  => forum_type,
      "forum_visibility" => forum_visibility,     
      "account_id"  =>  account_id
     }
    end

end
