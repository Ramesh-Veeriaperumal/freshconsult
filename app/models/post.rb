class Post < ActiveRecord::Base
  def self.per_page() 25 end
  validates_presence_of :user_id, :body_html, :topic
  
  belongs_to :forum
  belongs_to :user
  belongs_to :topic
  
  named_scope :answered_posts, :conditions => { :answer => true }
  
  has_many :attachments,
    :as => :attachable,
    :class_name => 'Helpdesk::Attachment',
    :dependent => :destroy

  #format_attribute :body
  before_create { |r| r.forum_id = r.topic.forum_id }
  before_save :set_body_content
  after_create  :update_cached_fields,:monitor_reply
  after_destroy :update_cached_fields

  
  attr_protected	:topic_id , :account_id , :attachments
  
  def editable_by?(user)
    user && (user.id == user_id || user.has_manage_forums? || user.moderator_of?(forum_id))
  end
  
  def to_xml(options = {})
    options[:except] ||= []
    options[:except] << :topic_title << :forum_name
    super
  end
  
  def monitor_reply
    send_later(:send_monitorship_emails)
  end
  
  def send_monitorship_emails
    topic.monitorships.active_monitors.each do |monitorship|
      PostMailer.deliver_monitor_email!(monitorship.user.email,self,self.user)
    end
  end
  
  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:except => [:account_id,:import_id]) 
  end
  
  protected
    # using count isn't ideal but it gives us correct caches each time
    def update_cached_fields
      Forum.update_all ['posts_count = ?', Post.count(:id, :conditions => {:forum_id => forum_id})], ['id = ?', forum_id]
      User.update_posts_count(user_id)
      topic.update_cached_post_fields(self)
  end
    def set_body_content        
      self.body = (self.body_html.gsub(/<\/?[^>]*>/, "")).gsub(/&nbsp;/i,"") unless self.body_html.empty?
    end
  
  
  
end
