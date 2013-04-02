class Forum < ActiveRecord::Base
  acts_as_list :scope => :forum_category
  include ActionController::UrlWriter

  has_many :activities, 
    :class_name => 'Helpdesk::Activity', 
    :as => 'notable'
  
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
    if user && user.has_manage_forums?
      vis_arr = VISIBILITY_NAMES_BY_KEY.keys
    elsif user
      vis_arr = [VISIBILITY_KEYS_BY_TOKEN[:anyone],VISIBILITY_KEYS_BY_TOKEN[:logged_users]]
    else
      vis_arr = [VISIBILITY_KEYS_BY_TOKEN[:anyone]]   
    end
  end


  named_scope :visible, lambda {|user| {
                    # :joins => "LEFT JOIN `customer_forums` ON customer_forums.forum_id = forums.id
                    #             and customer_forums.account_id = forums.account_id ",
                    :conditions => visiblity_condition(user) } }


  def self.visiblity_condition(user)
    condition =  {:forum_visibility =>self.visibility_array(user) }
    condition =  Forum.merge_conditions(condition) + " OR 
                  ( forum_visibility = #{Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users]} 
                    AND forums.id IN (SELECT customer_forums.forum_id from customer_forums
                                      where customer_forums.customer_id = #{user.customer_id} and 
                                      customer_forums.account_id = #{user.account_id}))"  if (user && user.has_company?)
                # customer_forums.customer_id = #{user.customer_id} )"  if (user && user.has_company?)
    return condition
  end

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
  has_many :recent_topics, :class_name => 'Topic', :order => 'sticky desc, replied_at DESC'
  has_one  :recent_topic,  :class_name => 'Topic', :order => 'replied_at DESC'
  has_many :posts,     :order => "#{Post.table_name}.created_at DESC", :dependent => :delete_all
  has_one  :recent_post, :order => "#{Post.table_name}.created_at DESC", :class_name => 'Post'
  has_many :customer_forums , :class_name => 'CustomerForum' , :dependent => :destroy
  
  format_attribute :description
  attr_protected :forum_category_id , :account_id
  xss_terminate  :html5lib_sanitize => [:description_html,:description]
 
  # after_save :set_topic_delta_flag
  before_update :clear_customer_forums
  
  def after_create 
    create_activity('new_forum')
  end

  def after_destroy 
    create_activity('delete_forum')
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
    return true if (user and user.has_manage_forums?)
    return true if self.forum_visibility == VISIBILITY_KEYS_BY_TOKEN[:anyone]
    return true if (user and (self.forum_visibility == VISIBILITY_KEYS_BY_TOKEN[:logged_users]))
    return true if (user && (self.forum_visibility == VISIBILITY_KEYS_BY_TOKEN[:company_users]) && 
      user.customer  && customer_forums.map(&:customer_id).include?(user.customer.id))
  end
  
  # def set_topic_delta_flag
  #   self.topics.each do |topic|
  #     topic.delta = true
  #     topic.save
  #   end
  # end
  
  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:include => options[:include],:except => [:account_id,:import_id]) 
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
                          :path => category_forum_path(forum_category_id, 
                                    id), 
                          'category_name' => h(forum_category.to_s), 
                          :url_params => {
                                           :category_id => forum_category_id, 
                                           :forum_id => id,
                                           :path_generator => 'category_forum_path'
                                          },
                          :title => h(to_s),
                          :version => 2
                        }
    )
  end
   
end
