class Post < ActiveRecord::Base
  include ActionController::UrlWriter

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

  named_scope :published_and_mine, lambda { |user| { :conditions => ["(published=1 OR user_id =?) AND (published=1 OR spam != 1 OR spam IS NULL)", user.id] } }
  named_scope :published, :conditions => {:published => true, :trash => false }
  named_scope :trashed, :conditions => {:trash => true }

  named_scope :include_topics_and_forums, :include => { :topic => [ :forum ] }
  named_scope :unpublished_spam,:conditions => {:published => false, :spam => true, :trash => false}, :order => "created_at DESC", :joins => [ :topic ]
  named_scope :waiting_for_approval,:conditions => {:published => false, :spam => false, :trash => false}, :order => "created_at DESC", :joins => [ :topic ]
  named_scope :unpublished,:conditions => {:published => false, :trash => false}, :order => "created_at DESC", :joins => [ :topic ]


  named_scope :by_user, lambda { |user|
      { :joins => [:topic],
        :conditions => ["posts.user_id = ? and posts.user_id != topics.user_id", user.id ]
      }
  }
  before_update :unmark_another_answer, :if => :questions? && :topic_has_answer?
  after_update :toggle_answered_stamp, :if => :questions?
  after_destroy :mark_as_unanswered, :if => :answer

  has_many_attachments
  has_many_cloud_files
  
  delegate :update_es_index, :to => :topic, :allow_nil => true
  delegate :questions?, :problems?, :to => :forum
  xss_sanitize :only => [:body_html],  :html_sanitize => [:body_html]
  #format_attribute :body

  attr_protected  :topic_id , :account_id , :attachments, :published, :spam
  after_create  :monitor_topic, :if => :can_monitor?

  SPAM_SCOPES = {
    :spam => :unpublished_spam,
    :waiting => :waiting_for_approval
  }

  SPAM_SCOPES_DYNAMO = {
    :spam => ForumSpam,
    :unpublished => ForumUnpublished
  }

  attr_accessor :request_params, :portal

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

  def as_json (options={})
    options[:except]=[:account_id,:import_id]
    json_str=super options
    return json_str
  end

  def to_liquid
    forum_post_drop ||= Forum::PostDrop.new self
  end

  def to_s
    topic.title
  end

  def original_post?
    topic.posts.first == self
  end

  def can_monitor?
    self.import_id.nil?
  end

  def monitor_topic
    monitorship = topic.monitorships.find_by_user_id(user.id)
    topic.monitorships.create(:user_id => user.id, :active => true, :portal_id => portal) unless monitorship
  end

  def toggle_answer
    update_attributes( :answer => !answer ) if questions?
  end

  def topic_has_answer?
    topic.answered?
  end

  def unmark_another_answer
    return unless answer_changed?
    topic.answer.toggle_answer if answer
  end

  def toggle_answered_stamp
    return unless answer_changed?
    topic.reload
    topic.update_attributes(:stamp_type => (answer ?
                                          Topic::QUESTIONS_STAMPS_BY_TOKEN[:answered] : Topic::QUESTIONS_STAMPS_BY_TOKEN[:unanswered]))
  end

  def mark_as_unanswered
    topic.update_attributes( :stamp_type => Topic::QUESTIONS_STAMPS_BY_TOKEN[:unanswered] )
  end

  def can_mark_as_answer?(current_user)
    (topic.forum.questions?) and (current_user == topic.user) and (current_user != user)
  end

  def approve!
    self.published = true
    self.save!
  end

  def mark_as_spam!
    self.published = false
    self.spam = true
    self.save
  end

  # Added for portal customisation drop
  def self.filter(_per_page = self.per_page, _page = 1)
    paginate :per_page => _per_page, :page => _page
  end

  def topic_path
    support_discussions_topic_path(topic)
  end

  def topic_url
    support_discussions_topic_url(topic, :host => account.host)
  end

end
