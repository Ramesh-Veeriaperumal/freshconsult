class Topic < ActiveRecord::Base
  self.primary_key = :id
  include Search::ElasticSearchIndex
  include Mobile::Actions::Topic

  include Redis::RedisKeys
  include Redis::OthersRedis
  
  HITS_CACHE_THRESHOLD = 100

  include Community::HitMethods
  include CloudFilesHelper

  acts_as_voteable
  validates_presence_of :forum, :user, :title
  validate :check_stamp_type

  concerned_with :merge, :esv2_methods

  belongs_to_account
  belongs_to :forum
  belongs_to :user
  belongs_to :last_post, :class_name => "Post", :foreign_key => 'last_post_id'

  before_create :set_locked
  before_save :set_sticky
  before_validation :set_unanswered_stamp, :if => :questions?, :on => :create
  before_validation :set_unsolved_stamp, :if => :problems?, :on => :create
  before_validation :assign_default_stamps, :mark_post_as_unanswered, :if => :forum_id_changed?, :on => :update
  
  # Callbacks will be executed in the order in which they have been included. 
  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher

  has_many :merged_topics, :class_name => "Topic", :foreign_key => 'merged_topic_id', :dependent => :nullify
  belongs_to :merged_into, :class_name => "Topic", :foreign_key => "merged_topic_id"

  has_many :monitorships, :as => :monitorable, :class_name => "Monitorship", :dependent => :destroy
  has_many :merged_monitorships,
           :as => :monitorable,
           :class_name => "Monitorship", 
           :through => :merged_topics,
           :source => :monitorships
  has_many :monitors, :through => :monitorships, :source => :user, 
                      :conditions => ["#{Monitorship.table_name}.active = ?", true],
                      :order => "#{Monitorship.table_name}.id DESC"

  has_many :posts, :order => "#{Post.table_name}.created_at", :dependent => :destroy #=> Changing after discussing with Shyam
  # previously posts had :dependant => :destroy
  # to delete all dependant post hile deleting a topic, destroy has been changed to delete all
  # as a result no callbacks will be triggered and so User.posts_count will not be updated
  has_one  :recent_post, :conditions => {:published => true}, :order => "#{Post.table_name}.id DESC", :class_name => 'Post'
  has_one  :first_post, :order => "#{Post.table_name}.id ASC", :class_name => 'Post', :autosave => true

  has_one :ticket_topic, :dependent => :destroy
  has_many :voices, :through => :posts, :source => :user, :uniq => true, :order => "#{Post.table_name}.id DESC"

  belongs_to :replied_by_user, :foreign_key => "replied_by", :class_name => "User"
  has_many :activities,
    :class_name => 'Helpdesk::Activity',
    :as => 'notable'

  delegate :problems?, :questions?, :to => :forum, :allow_nil => true # delegation precedes validations, if allow_nil is removed and forum is nil this line throws error
  delegate :type_name, :to => :forum, :allow_nil => true # delegation precedes validations, if allow_nil is removed and forum is nil this line throws error

  scope :newest, -> { order 'replied_at DESC' }

  scope :visible, -> (user) { visiblity_options(user) }

  scope :by_user, -> (user) { where ["user_id = ?", user.id ] }

  scope :published, -> { where(published: true) }

  scope :as_list_view, -> { 
            where(published: true).
            includes(last_post: [:user], forum: [], user: [])
          }

  scope :as_activities, -> {
          where(published: true).
          includes(last_post: [:user], forum: []).
          order("#{Topic.table_name}.replied_at DESC")
        }


  scope :scope_by_forum_category_id, -> (forum_category_id) {
          where(["forums.forum_category_id = ?", forum_category_id]).
          joins(%(INNER JOIN forums ON forums.id = topics.forum_id AND
                    forums.account_id = topics.account_id))
        }

  scope :followed_by, -> (user_id) {
          where(["monitorships.active=? and monitorships.user_id = ?",true, user_id],).
          joins(%(INNER JOIN monitorships on topics.id = monitorships.monitorable_id 
            and monitorships.monitorable_type = 'Topic' 
            and topics.account_id = monitorships.account_id))
        } # Used by monitorship APIs

  scope :participated_by, -> (user_id) {
          where(["topics.id IN (select topic_id from posts where posts.user_id = ? )", user_id])
        }

  scope :following, -> (ids) {
          where(following_conditions(ids)).
          order("#{Topic.table_name}.replied_at DESC")
        }

  scope :published_and_unmerged, -> { where(published: true, merged_topic_id: nil) }

  scope :topics_for_portal, -> (portal) { 
          joins(%( INNER JOIN forums AS f ON f.id = topics.forum_id )).
          where([' f.forum_category_id IN (?)', portal.portal_forum_categories.map(&:forum_category_id)])
        }

  # The below namescope might be used later. DO NOT DELETE. @Thanashyam
  # scope :followed_by, lambda { |user_id|
  #   {
  #     :joins => %(  LEFT JOIN `forums` ON `forums`.`id` = `topics`.`forum_id`
  #                   INNER JOIN `monitorships` ON 
  #                       ( `monitorships`.`monitorable_id`=`topics`.`id` AND 
  #                         `monitorships`.`monitorable_type`="Topic" AND
  #                         `monitorships`.`account_id`=`topics`.`account_id`
  #                       ) 
  #                     OR 
  #                       ( 
  #                         `monitorships`.`monitorable_id`=`forums`.`id` AND
  #                         `monitorships`.`monitorable_type`="Forum" AND
  #                         `monitorships`.`account_id`=`forums`.`account_id`
  #                       )),
  #     :conditions => ["monitorships.user_id=? AND monitorships.active=?", user_id, true],
  #     :order => "#{Topic.table_name}.replied_at DESC"
  #   }
  # }

  # Popular topics in forums
  # Filtered based on last replied and user_votes
  # !FORUM ENHANCE Removing hits from orderby of popular as it will return all time
  # It would be better if it can be tracked month wise
  # Generally with days before DateTime.now - 30.days
  scope :popular, -> (days_before) {
            where(["replied_at >= ?", days_before],).
            order("#{Topic.table_name}.user_votes DESC, hits DESC, replied_at DESC").
            includes(:last_post)
          }

  scope :sort_by_popular, -> { order("#{Topic.table_name}.user_votes DESC, hits DESC, replied_at DESC") }
  
  # The below named scopes are used in fetching topics with a specific stamp used for portal topic list
  scope :by_stamp, -> (stamp_type) { where(stamp_type: stamp_type) }

  scope :unmerged, -> { where(merged_topic_id: nil) }

  attr_accessor :trash, :publishing

  def self.visiblity_options(user)
    if user
       if user.privilege?(:manage_tickets)
          {}
       else
          { :include => [:forum =>:customer_forums],
            :conditions =>["forums.forum_visibility in(?) OR (forums.forum_visibility = ? and customer_forums.customer_id in (?))" ,
                           Forum.visibility_array(user) , Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users], user.company_ids_str]
          }
       end
    else
      {
        :include =>[:forum],:conditions => ["forums.forum_visibility = ?" , Forum::VISIBILITY_KEYS_BY_TOKEN[:anyone]]
      }
    end
  end

  def self.following_conditions(ids)
    return "" if ids.blank?
    sql = []
    sql << "`#{Topic.table_name}`.`id` IN (?)" unless ids[:topic].blank?
    sql << "`#{Topic.table_name}`.`forum_id` IN (?)" unless ids[:forum].blank?

    [sql.join(" OR ")] | ([ids[:topic], ids[:forum]] - [[]])
  end

  scope :for_forum, ->(forum){
    where(["forum_id = ? ", forum])
  }

  scope :freshest, ->(account){
    where(["account_id = ? ", account])
    .order('topics.replied_at DESC')
  }

  attr_protected :forum_id , :account_id, :published
  # to help with the create form
  attr_accessor :body_html, :highlight_title, :sort_by

  IDEAS_STAMPS = [
    [ :planned,      "topic.ideas_stamps.planned",       1 ],
    [ :inprogress,   "topic.ideas_stamps.inprogress",    4 ],
    [ :deferred,     "topic.ideas_stamps.deferred",      5 ],
    [ :implemented,  "topic.ideas_stamps.implemented",   2 ],
    [ :nottaken,     "topic.ideas_stamps.nottaken",      3 ]
  ]

  IDEAS_STAMPS_OPTIONS = IDEAS_STAMPS.map { |i| [i[1], i[2]] }
  IDEAS_STAMPS_BY_KEY = Hash[*IDEAS_STAMPS.map { |i| [i[2], i[1]] }.flatten]
  IDEAS_STAMPS_BY_TOKEN = Hash[*IDEAS_STAMPS.map { |i| [i[0], i[2]] }.flatten]
  IDEAS_STAMPS_NAMES_BY_TOKEN = Hash[*IDEAS_STAMPS.map { |i| [i[0], i[1]] }.flatten]
  IDEAS_STAMPS_TOKEN_BY_KEY = Hash[*IDEAS_STAMPS.map { |i| [i[2], i[0]] }.flatten]
  IDEAS_TOKENS = IDEAS_STAMPS.map { |i| i[0] }

  QUESTIONS_STAMPS = [
    [ :answered,     "topic.questions.answered",      6 ],
    [ :unanswered,   "topic.questions.unanswered",    7 ]
  ]

  QUESTIONS_STAMPS_OPTIONS = QUESTIONS_STAMPS.map { |i| [i[1], i[2]] }
  QUESTIONS_STAMPS_BY_KEY = Hash[*QUESTIONS_STAMPS.map { |i| [i[2], i[1]] }.flatten]
  QUESTIONS_STAMPS_BY_TOKEN = Hash[*QUESTIONS_STAMPS.map { |i| [i[0], i[2]] }.flatten]
  QUESTIONS_STAMPS_NAMES_BY_TOKEN = Hash[*QUESTIONS_STAMPS.map { |i| [i[0], i[1]] }.flatten]
  QUESTIONS_STAMPS_TOKEN_BY_KEY = Hash[*QUESTIONS_STAMPS.map { |i| [i[2], i[0]] }.flatten]
  QUESTIONS_TOKENS = QUESTIONS_STAMPS.map { |i| i[0] }

  PROBLEMS_STAMPS = [
    [ :solved,     "topic.problems.solved",      8 ],
    [ :unsolved,   "topic.problems.unsolved",    9 ]
  ]

  PROBLEMS_STAMPS_OPTIONS = PROBLEMS_STAMPS.map { |i| [i[1], i[2]] }
  PROBLEMS_STAMPS_BY_KEY = Hash[*PROBLEMS_STAMPS.map { |i| [i[2], i[1]] }.flatten]
  PROBLEMS_STAMPS_BY_TOKEN = Hash[*PROBLEMS_STAMPS.map { |i| [i[0], i[2]] }.flatten]
  PROBLEMS_STAMPS_NAMES_BY_TOKEN = Hash[*PROBLEMS_STAMPS.map { |i| [i[0], i[1]] }.flatten]
  PROBLEMS_STAMPS_TOKEN_BY_KEY = Hash[*PROBLEMS_STAMPS.map { |i| [i[2], i[0]] }.flatten]
  PROBLEMS_TOKENS = PROBLEMS_STAMPS.map { |i| i[0] }

  ALL_TOKENS = {
    Forum::TYPE_KEYS_BY_TOKEN[:howto] => QUESTIONS_TOKENS,
    Forum::TYPE_KEYS_BY_TOKEN[:problem] => PROBLEMS_TOKENS,
    Forum::TYPE_KEYS_BY_TOKEN[:ideas] => IDEAS_TOKENS,
    Forum::TYPE_KEYS_BY_TOKEN[:announce] => [],
  }

  ALL_TOKENS_FOR_FILTER = {
    Forum::TYPE_KEYS_BY_TOKEN[:howto] => QUESTIONS_STAMPS_BY_KEY,
    Forum::TYPE_KEYS_BY_TOKEN[:problem] => PROBLEMS_STAMPS_BY_KEY,
    Forum::TYPE_KEYS_BY_TOKEN[:ideas] => IDEAS_STAMPS_BY_KEY,
    Forum::TYPE_KEYS_BY_TOKEN[:announce] => {},
  }
  STAMPS_BY_KEY = IDEAS_STAMPS_BY_TOKEN.merge(QUESTIONS_STAMPS_BY_TOKEN).merge(PROBLEMS_STAMPS_BY_TOKEN)
  NAMES_BY_KEY = IDEAS_STAMPS_NAMES_BY_TOKEN.merge(QUESTIONS_STAMPS_NAMES_BY_TOKEN).merge(PROBLEMS_STAMPS_NAMES_BY_TOKEN)
  STAMPS_TOKEN_BY_KEY = IDEAS_STAMPS_TOKEN_BY_KEY.merge(QUESTIONS_STAMPS_TOKEN_BY_KEY).merge(PROBLEMS_STAMPS_TOKEN_BY_KEY)

  DEFAULT_STAMPS_BY_FORUM_TYPE = {
    Forum::TYPE_KEYS_BY_TOKEN[:howto] => QUESTIONS_STAMPS_BY_TOKEN[:unanswered],
    Forum::TYPE_KEYS_BY_TOKEN[:problem] => PROBLEMS_STAMPS_BY_TOKEN[:unsolved]
  }

  TOPIC_ATTR_TO_REMOVE = ["int_tc01", "int_tc02", "int_tc03", "int_tc04", "int_tc05", 
    "long_tc01", "long_tc02", "datetime_tc01", "datetime_tc02", "boolean_tc01", "boolean_tc02", "string_tc01", 
    "string_tc02", "text_tc01", "text_tc02"]
    
  FORUM_TO_STAMP_TYPE = {
    Forum::TYPE_KEYS_BY_TOKEN[:announce] => [nil],
    Forum::TYPE_KEYS_BY_TOKEN[:ideas] => IDEAS_STAMPS_BY_KEY.keys + [nil], # nil should always be last, if not, revisit check_stamp_type
    Forum::TYPE_KEYS_BY_TOKEN[:problem] => PROBLEMS_STAMPS_BY_KEY.keys,
    Forum::TYPE_KEYS_BY_TOKEN[:howto] => QUESTIONS_STAMPS_BY_KEY.keys
  }

  def self.ideas_stamps_list
    IDEAS_STAMPS.map { |i| [I18n.t(i[1]), i[2]] }
  end

  def self.ideas_stamp_keys
    Hash[*IDEAS_STAMPS.map { |i| [i[2], I18n.t(i[1])] }.flatten]
  end

  def self.names_by_keys
    Hash[*NAMES_BY_KEY.map { |i| [i[0], I18n.t(i[1])] }.flatten]
  end

  def self.all_tokens_for_filters
    Hash[*ALL_TOKENS_FOR_FILTER.map {|i| [i[0],  Hash[*i[1].map { |k| [k[0], I18n.t(k[1])] }.flatten]]}.flatten]
  end

  def check_stamp_type
    if forum
      is_valid = FORUM_TO_STAMP_TYPE[forum.forum_type].include?(stamp_type)
      is_valid &&= check_answers if questions?
      errors.add(:stamp_type, "is not valid") unless is_valid
    end
  end

  def check_answers
    stamp_type == QUESTIONS_STAMPS_BY_TOKEN[:answered] ? posts.any?(&:answer) : !posts.any?(&:answer)
  end

  def monitorship_emails
    user_emails = Array.new
    for monitorship in self.monitorships.active_monitors
      user_emails = monitorships.collect {|a| a.user.email}
    end
    return user_emails.compact
  end

  def new?
    posts_count < 2
  end

  def stamp_name
    self.class.ideas_stamp_keys[stamp_type]
  end

  def stamp_key
    IDEAS_STAMPS_TOKEN_BY_KEY[stamp_type].to_s
  end

  def stamp?
    (stamp_type? && self.class.all_tokens_for_filters[forum.forum_type].present? && 
      self.class.all_tokens_for_filters[forum.forum_type].keys.include?(stamp_type))
  end

  def stamp
    stamp? ? 
      self.class.all_tokens_for_filters[forum.forum_type][stamp_type] : 
      self.class.all_tokens_for_filters[forum.forum_type][DEFAULT_STAMPS_BY_FORUM_TYPE[forum.forum_type]]
  end

  def reply_count
    [posts_count - 1, 0].max
  end

  def sticky?() sticky == 1 end

  def views() hits end

  def paged?() posts_count > Post.per_page end

  def set_locked
    self.locked = false if self.locked.nil?
    true
  end

  def set_sticky
    self.sticky = 0 if self.sticky.nil?
    true
  end

  def set_unanswered_stamp
    self.stamp_type ||= Topic::QUESTIONS_STAMPS_BY_TOKEN[:unanswered]
  end

  def set_unsolved_stamp
    self.stamp_type ||= Topic::PROBLEMS_STAMPS_BY_TOKEN[:unsolved]
  end

  def last_page
    [(posts_count.to_f / Post.per_page).ceil.to_i, 1].max
  end

  def update_cached_post_fields(post)
    # these fields are not accessible to mass assignment
    # remaining_post = post.frozen? ? recent_post : post
    # ASK WHY WE ARE CHECKING THIS
    if recent_post
      self.class.where(['id = ?', id]).update_all(['replied_at = ?, replied_by = ?, last_post_id = ?, posts_count = ?',
        recent_post.created_at, recent_post.user_id, recent_post.id, posts.published.count])
    # else
      # self.destroy
    end
  end

  STAMPS_BY_KEY.keys.each do |method|
    define_method "#{method}?" do
      stamp_type == STAMPS_BY_KEY[method]
    end
  end

  def answer
    posts.answered_posts.first
  end

  def toggle_solved_stamp
    return unless problems?
    update_attributes(:stamp_type => (solved? ?
                    Topic::PROBLEMS_STAMPS_BY_TOKEN[:unsolved] : Topic::PROBLEMS_STAMPS_BY_TOKEN[:solved]))
  end

  def last_post_url
    if self.last_post_id.present?
      Rails.application.routes.url_helpers.support_discussions_topic_path(self, :anchor => "post-#{self.last_post_id}")
    end
  end

  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:include => options[:include],:except => ([:account_id,:import_id]+TOPIC_ATTR_TO_REMOVE))
  end

  def as_json(options = {})
    options[:except] = ((options[:except] || []) +  TOPIC_ATTR_TO_REMOVE).uniq
    super(options)
  end

  # Added for portal customisation drop
  def self.filter(_per_page = self.per_page, _page = 1)
    paginate :per_page => _per_page, :page => _page
  end

  # Added for portal customisation
  def to_liquid
    @forum_topic_drop ||= Forum::TopicDrop.new self
  end

  def to_s
    title
  end

  def topic_changes
    @topic_changes ||= self.changes.clone
  end

  def topic_desc
    truncate(self.posts.first.body.gsub(/<\/?[^>]*>/, ""), :length => 300)
  end

  def approve!
    self.published = true
    self.save!
  end

  def spam_count
    SpamCounter.count(id, :spam)
  end

  def unpublished_count
    SpamCounter.count(id, :unpublished)
  end

  def has_unpublished_posts?
    spam_count > 0 || unpublished_count > 0
  end
  
  def hit_key
    TOPIC_HIT_TRACKER % {:account_id => account_id, :topic_id => id }
  end

  def unsubscribed_agents
    user_ids = monitors.map(&:id)
    Sharding.run_on_slave { account.agents_hash_from_cache.except(*user_ids) }
  end
  
  def assign_default_stamps
    if forum && !stamp_type_changed? && forum_was.forum_type != forum.forum_type
      self.stamp_type = Topic::DEFAULT_STAMPS_BY_FORUM_TYPE[forum.forum_type]
    end
  end

  def mark_post_as_unanswered
    posts.answered_posts.map(&:toggle_answer) if forum && forum_was.questions? && !forum.questions?
  end

  def forum_was
    @old_forum_cached ||= Forum.find(forum_id_was) if forum_id_was
  end

  def to_rmq_json(keys,action)
    topic_identifiers
  end

  def topic_identifiers
    @rmq_topic_identifiers ||= {
      "id"          =>  id,
      "user_id"     =>  user_id,
      "forum_id"    =>  forum_id,
      "account_id"  =>  account_id,
      "published"   =>  published,
      "answer"      =>  answer,
    }
  end

  def ticket
    ticket_topic.ticketable if ticket_topic
  end

  def create_post_from_ticket_note(ticket_note)
    @post = posts.build(body_html: ticket_note.body_html, user_id: ticket_note.user_id)
    inline_attachments_map = {}
    ticket_note.all_attachments.each do |attachment|
      @post.attachments.build(content: attachment.to_io)
    end
    ticket_note.inline_attachments.each do |attachment|
      inline_attachments_map[attachment.inline_url] = @post.inline_attachments.build(content: attachment.to_io, attachable_type: 'Forums Image Upload')
    end
    clone_cloud_files_attachments(ticket_note, @post)

    # save this to generate ids for inline attachments
    @post.save!

    # replace inline urls of note body html to copied attachments if there is any
    unless ticket_note.inline_attachments.empty?
      body_html = @post.body_html
      @post = account.posts.find(@post.id) # Hack, @post.reload is not working even if we change body_html.
      inline_attachments_map.each do |inline_url, attachment_copy|
        body_html.gsub!(inline_url, attachment_copy.inline_url)
      end
      @post.body_html = body_html
      @post.save!
    end
  rescue Exception => e # rubocop:disable RescueException
    Rails.logger.debug "Error while creating post from ticket note::: #{e.message}, Account:: [#{ticket_note.account_id},#{ticket_note.id} "
    NewRelic::Agent.notice_error(e)
  end
end
