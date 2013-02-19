class Post < ActiveRecord::Base
  def self.per_page() 25 end
  validates_presence_of :user_id, :body_html, :topic

  belongs_to_account
  
  belongs_to :forum
  belongs_to :user
  belongs_to :topic
  
  has_many :activities, 
    :class_name => 'Helpdesk::Activity', 
    :as => 'notable'

  named_scope :answered_posts, :conditions => { :answer => true }
  has_many :support_scores, :as => :scorable, :dependent => :destroy

  named_scope :by_user, lambda { |user|
      { :joins => [:topic],
        :conditions => ["posts.user_id = ? and posts.user_id != topics.user_id", user.id ] 
      }
  }
  
  has_many_attachments

  #format_attribute :body
  
  attr_protected	:topic_id , :account_id , :attachments
  
  def editable_by?(user)
    user && (user.id == user_id || user.has_manage_forums? || user.moderator_of?(forum_id))
  end
  
  def to_xml(options = {})
    options[:except] ||= []
    options[:except] << :topic_title << :forum_name
    super
  end
  
  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:except => [:account_id,:import_id]) 
  end

  def to_liquid
    forum_post_drop ||= Forum::PostDrop.new self
  end

  def to_s
    topic.title
  end
  
end
