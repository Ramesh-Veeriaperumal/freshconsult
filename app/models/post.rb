class Post < ActiveRecord::Base
  
  include Juixe::Acts::Voteable

  SORT_ORDER = {
    :date => 'created_at ASC',
    :popularity => 'user_votes DESC',
    :recency => 'created_at DESC'
  }

  acts_as_voteable

  self.primary_key = :id
  def self.per_page() 25 end
  validates_presence_of :user_id, :body_html, :topic

  concerned_with :esv2_methods, :presenter

  publishable on: [:create]

  belongs_to_account

  belongs_to :forum
  belongs_to :user
  belongs_to :topic

  has_many :activities,
    :class_name => 'Helpdesk::Activity',
    :as => 'notable'

  scope :answered_posts, :conditions => { :answer => true }
  has_many :support_scores, :as => :scorable, :dependent => :destroy
  
  scope :published_and_mine, lambda { |user| { :conditions => ["(published=1 OR user_id =?) AND (published=1 OR spam != 1 OR spam IS NULL)", user.id] } }
  scope :published, :conditions => {:published => true, :trash => false }
  scope :trashed, :conditions => {:trash => true }

  scope :include_topics_and_forums, :include => { :topic => [ :forum ] }
  scope :unpublished_spam,:conditions => {:published => false, :spam => true, :trash => false}, :order => "posts.created_at DESC", :joins => [ :topic ]
  scope :waiting_for_approval,:conditions => {:published => false, :spam => false, :trash => false}, :order => "posts.created_at DESC", :joins => [ :topic ]
  scope :unpublished,:conditions => {:published => false, :trash => false}, :order => "posts.created_at DESC", :joins => [ :topic ]


  scope :by_user, lambda { |user|
      { :joins => [:topic],
        :conditions => ["posts.user_id = ?  and posts.user_id != topics.user_id", user.id ]
      }
  }
  before_update :unmark_another_answer, :if => :questions? && :topic_has_answer?
  after_update :toggle_answered_stamp, :if => :questions?
  after_destroy :mark_as_unanswered, :if => :answer
  
  has_many_attachments
  has_many_cloud_files
  
  delegate :update_es_index, :to => :topic, :allow_nil => true
  
  delegate :questions?, :problems?, :to => :forum
  xss_sanitize :only => [:body_html],  :post_sanitizer => [:body_html]
  #format_attribute :body

  attr_protected  :topic_id , :account_id , :attachments, :published, :spam
  after_create  :monitor_topic, :if => :can_monitor?
  
  # Callbacks will be executed in the order in which they have been included. 
  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher

  SPAM_SCOPES = {
    :spam => :unpublished_spam,
    :waiting => :waiting_for_approval
  }

  SPAM_SCOPES_DYNAMO = {
    :spam => ForumSpam,
    :unpublished => ForumUnpublished
  }

  REPORT = {
    :ham => true,
    :spam => false
  }

  attr_accessor :request_params, :portal
  
  def to_xml(options = {})
    options[:except] ||= []
    options[:except] << :topic_title << :forum_name
    super
  end

  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:except => [:account_id,:import_id])
  end

  def as_json (options={})
    options[:except]=[:account_id,:import_id]
    super options
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
    Rails.application.routes.url_helpers.support_discussions_topic_path(topic)
  end

  def topic_url
    Rails.application.routes.url_helpers.support_discussions_topic_url(topic, :host => account.host)
  end

  def to_rmq_json(keys,action)
    post_identifiers
    #destroy_action?(action) ? post_identifiers : return_specific_keys(post_identifiers, keys)
  end

  def post_identifiers
    @rmq_post_identifiers ||= {
      "id"          =>  id,
      "user_id"     =>  user_id,
      "topic_id"    =>  topic_id,
      "forum_id"    =>  forum_id,
      "account_id"  =>  account_id,
      "published"   =>  published,
      "answer"      =>  answer,
    }
  end

end
