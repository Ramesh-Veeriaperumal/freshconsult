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

  delegate :update_es_index, :to => :topic, :allow_nil => true

  #format_attribute :body
  
  attr_protected	:topic_id , :account_id , :attachments
    
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

  # Added for portal customisation drop
  def self.filter(_per_page = self.per_page, _page = 1)
    paginate :per_page => _per_page, :page => _page
  end
  
end
