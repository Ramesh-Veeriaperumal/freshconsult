class ForumCategory < ActiveRecord::Base
  validates_presence_of :name,:account_id
  validates_uniqueness_of :name, :scope => :account_id

  def self.company_specific?(user)
    (user && user.has_company?)
  end

  def self.user_forums_condition
    condition = ['forum_visibility not in (?) ', [Forum::VISIBILITY_KEYS_BY_TOKEN[:agents] ,  Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users]]]
    condition = ForumCategory.merge_conditions(condition) + " OR ( forum_visibility = #{Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users]} AND 
                customer_forums.customer_id = #{User.current.customer_id} )" if company_specific?(User.current)
    return condition
  end

  has_many :forums, :dependent => :destroy, :order => "position"
  has_many :customer_forums , :class_name => "CustomerForum", :through => :forums 
  has_many :portal_forums, :class_name => 'Forum', :conditions =>{:forum_visibility => Forum::VISIBILITY_KEYS_BY_TOKEN[:anyone]} , :order => "position" 
  has_many :user_forums, :class_name => 'Forum', :include =>[:customer_forums] ,:conditions => user_forums_condition, :order => "position"
  has_many :portal_topics, :through => :portal_forums
  has_many :user_topics, :through => :user_forums
  
  attr_accessible :name,:description , :import_id
  belongs_to :account
  
  acts_as_list :scope => :account  

  # retrieves forums ordered by position
  def self.find_ordered(account, options = {})
    find :all, options.update(:conditions => {:account_id => account}, :order => 'name')
  end
  
  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:include => options[:include],:except => [:account_id,:import_id]) 
  end
  
  
 end
