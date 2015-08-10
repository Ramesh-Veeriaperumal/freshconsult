class Topic < ActiveRecord::Base
  self.primary_key = :id
  include Search::ElasticSearchIndex
  include Mobile::Actions::Topic
  
  include Redis::RedisKeys
  include Redis::OthersRedis
  
  HITS_CACHE_THRESHOLD = 100

  include Community::HitMethods
  
  acts_as_voteable
  validates_presence_of :forum, :user, :title
  validate :check_stamp_type

  concerned_with :merge

  belongs_to_account
  belongs_to :forum
  belongs_to :user
  belongs_to :last_post, :class_name => "Post", :foreign_key => 'last_post_id'

  before_create :set_locked
  before_save :set_sticky
  before_validation :set_unanswered_stamp, :if => :questions?, :on => :create
  before_validation :set_unsolved_stamp, :if => :problems?, :on => :create
  before_validation :assign_default_stamps, :if => :forum_id_changed?, :on => :update

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

  has_many :posts, :order => "#{Post.table_name}.created_at", :dependent => :delete_all
  # previously posts had :dependant => :destroy
  # to delete all dependant post hile deleting a topic, destroy has been changed to delete all
  # as a result no callbacks will be triggered and so User.posts_count will not be updated
  has_one  :recent_post, :conditions => {:published => true}, :order => "#{Post.table_name}.id DESC", :class_name => 'Post'
  has_one  :first_post, :order => "#{Post.table_name}.id ASC", :class_name => 'Post', :autosave => true

  has_one :ticket_topic, :dependent => :destroy
  has_one :ticket,:through => :ticket_topic

  has_many :voices, :through => :posts, :source => :user, :uniq => true, :order => "#{Post.table_name}.id DESC"

  belongs_to :replied_by_user, :foreign_key => "replied_by", :class_name => "User"
  has_many :activities,
    :class_name => 'Helpdesk::Activity',
    :as => 'notable'

  delegate :problems?, :questions?, :to => :forum, :allow_nil => true # delegation precedes validations, if allow_nil is removed and forum is nil this line throws error
  delegate :type_name, :to => :forum, :allow_nil => true # delegation precedes validations, if allow_nil is removed and forum is nil this line throws error

  scope :newest, :order => 'replied_at DESC'

  scope :visible, lambda {|user| visiblity_options(user) }

  scope :by_user, lambda { |user| { :conditions => ["user_id = ?", user.id ] } }

  scope :published, :conditions => { :published => true }

  scope :as_list_view,
      :conditions => { :published => true },
      :include => {:last_post => [:user], :forum => [], :user => []}

  scope :as_activities,
      :conditions => { :published => true },
      :include => {:last_post => [:user], :forum => []},
      :order => "#{Topic.table_name}.replied_at DESC"

  scope :scope_by_forum_category_id, lambda { |forum_category_id|
    { :joins => %(INNER JOIN forums ON forums.id = topics.forum_id AND
        forums.account_id = topics.account_id),
      :conditions => ["forums.forum_category_id = ?", forum_category_id],
    }
  }

  scope :followed_by, lambda { |user_id|
    { :joins => %(INNER JOIN monitorships on topics.id = monitorships.monitorable_id 
                  and monitorships.monitorable_type = 'Topic' 
                  and topics.account_id = monitorships.account_id),
      :conditions => ["monitorships.active=? and monitorships.user_id = ?",true, user_id],
    }
  } # Used by monitorship APIs

  scope :following, lambda { |ids|
    {
      :conditions => following_conditions(ids),
      :order => "#{Topic.table_name}.replied_at DESC"
    }
  }

  scope :published_and_unmerged, :conditions => { :published => true, :merged_topic_id => nil }

  scope :topics_for_portal, lambda { |portal|
    {
      :joins => %( INNER JOIN forums AS f ON f.id = topics.forum_id ),
      :conditions => [' f.forum_category_id IN (?)',
          portal.portal_forum_categories.map(&:forum_category_id)]
    }
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
  scope :popular, lambda { |days_before|
    { :conditions => ["replied_at >= ?", days_before],
      :order => "hits DESC, #{Topic.table_name}.user_votes DESC, replied_at DESC",
      :include => :last_post }
  }

  scope :sort_by_popular,
      :order => "#{Topic.table_name}.user_votes DESC, hits DESC, replied_at DESC"


  # The below named scopes are used in fetching topics with a specific stamp used for portal topic list
  scope :by_stamp, lambda { |stamp_type|
    { :conditions => ["stamp_type = ?", stamp_type] }
  }

  scope :unmerged, :conditions => { :merged_topic_id => nil }

  attr_accessor :trash

  def self.visiblity_options(user)
    if user
       if user.privilege?(:manage_tickets)
          {}
       else
          { :include => [:forum =>:customer_forums],
            :conditions =>["forums.forum_visibility in(?) OR (forums.forum_visibility = ? and customer_forums.customer_id =?)" ,
                           Forum.visibility_array(user) , Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users] ,user.company_id]
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

  scope :for_forum, lambda { |forum|
    { :conditions => ["forum_id = ? ", forum]
    }
  }
  # scope :limit, lambda { |num| { :limit => num } }
  scope :freshest, lambda { |account|
    { :conditions => ["account_id = ? ", account],
      :order => "topics.replied_at DESC"
    }
  }

  attr_protected :forum_id , :account_id, :published
  # to help with the create form
  attr_accessor :body_html, :highlight_title, :sort_by

  IDEAS_STAMPS = [
    [ :planned,      I18n.t("topic.ideas_stamps.planned"),       1 ],
    [ :inprogress,   I18n.t("topic.ideas_stamps.inprogress"),    4 ],
    [ :deferred,     I18n.t("topic.ideas_stamps.deferred"),      5 ],
    [ :implemented,  I18n.t("topic.ideas_stamps.implemented"),   2 ],
    [ :nottaken,     I18n.t("topic.ideas_stamps.nottaken"),      3 ]
  ]

  IDEAS_STAMPS_OPTIONS = IDEAS_STAMPS.map { |i| [i[1], i[2]] }
  IDEAS_STAMPS_BY_KEY = Hash[*IDEAS_STAMPS.map { |i| [i[2], i[1]] }.flatten]
  IDEAS_STAMPS_BY_TOKEN = Hash[*IDEAS_STAMPS.map { |i| [i[0], i[2]] }.flatten]
  IDEAS_STAMPS_NAMES_BY_TOKEN = Hash[*IDEAS_STAMPS.map { |i| [i[0], i[1]] }.flatten]
  IDEAS_STAMPS_TOKEN_BY_KEY = Hash[*IDEAS_STAMPS.map { |i| [i[2], i[0]] }.flatten]
  IDEAS_TOKENS = IDEAS_STAMPS.map { |i| i[0] }

  QUESTIONS_STAMPS = [
    [ :answered,     I18n.t("topic.questions.answered"),      6 ],
    [ :unanswered,   I18n.t("topic.questions.unanswered"),    7 ]
  ]

  QUESTIONS_STAMPS_OPTIONS = QUESTIONS_STAMPS.map { |i| [i[1], i[2]] }
  QUESTIONS_STAMPS_BY_KEY = Hash[*QUESTIONS_STAMPS.map { |i| [i[2], i[1]] }.flatten]
  QUESTIONS_STAMPS_BY_TOKEN = Hash[*QUESTIONS_STAMPS.map { |i| [i[0], i[2]] }.flatten]
  QUESTIONS_STAMPS_NAMES_BY_TOKEN = Hash[*QUESTIONS_STAMPS.map { |i| [i[0], i[1]] }.flatten]
  QUESTIONS_STAMPS_TOKEN_BY_KEY = Hash[*QUESTIONS_STAMPS.map { |i| [i[2], i[0]] }.flatten]
  QUESTIONS_TOKENS = QUESTIONS_STAMPS.map { |i| i[0] }

  PROBLEMS_STAMPS = [
    [ :solved,     I18n.t("topic.problems.solved"),      8 ],
    [ :unsolved,   I18n.t("topic.problems.unsolved"),    9 ]
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

  DEFAULT_STAMPS_BY_FORUM_TYPE = {
    Forum::TYPE_KEYS_BY_TOKEN[:howto] => QUESTIONS_STAMPS_BY_TOKEN[:unanswered],
    Forum::TYPE_KEYS_BY_TOKEN[:problem] => PROBLEMS_STAMPS_BY_TOKEN[:unsolved]
  }

  TOPIC_ATTR_TO_REMOVE = ["int_tc01", "int_tc02", "int_tc03", "int_tc04", "int_tc05", 
    "long_tc01", "long_tc02", "datetime_tc01", "datetime_tc02", "boolean_tc01", "boolean_tc02", "string_tc01", 
    "string_tc02", "text_tc01", "text_tc02"]
    
  FORUM_TO_STAMP_TYPE = {
    Forum::TYPE_KEYS_BY_TOKEN[:announce] => [nil],
    Forum::TYPE_KEYS_BY_TOKEN[:ideas] => IDEAS_STAMPS_BY_KEY.keys + [nil],
    Forum::TYPE_KEYS_BY_TOKEN[:problem] => PROBLEMS_STAMPS_BY_KEY.keys,
    Forum::TYPE_KEYS_BY_TOKEN[:howto] => QUESTIONS_STAMPS_BY_KEY.keys
  }

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
    IDEAS_STAMPS_BY_KEY[stamp_type]
  end

  def stamp_key
    IDEAS_STAMPS_TOKEN_BY_KEY[stamp_type].to_s
  end

  def stamp?
    stamp_type? && Topic::ALL_TOKENS_FOR_FILTER[forum.forum_type].present? && ALL_TOKENS_FOR_FILTER[forum.forum_type].keys.include?(stamp_type)
  end

  def stamp
    stamp? ? 
      ALL_TOKENS_FOR_FILTER[forum.forum_type][stamp_type] : 
      ALL_TOKENS_FOR_FILTER[forum.forum_type][DEFAULT_STAMPS_BY_FORUM_TYPE[forum.forum_type]]
  end

  def reply_count
    [posts_count - 1, 0].max
  end

  def sticky?() sticky == 1 end

  def views() hits end

  def paged?() posts_count > Post.per_page end

  def set_locked
    self.locked = false if self.locked.nil?
  end

  def set_sticky
    self.sticky = 0 if self.sticky.nil?
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
      self.class.update_all(['replied_at = ?, replied_by = ?, last_post_id = ?, posts_count = ?',
        recent_post.created_at, recent_post.user_id, recent_post.id, posts.published.count], ['id = ?', id])
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

  def to_indexed_json
    as_json(
          :root => "topic",
          :tailored_json => true,
          :only => [ :title, :user_id, :forum_id, :account_id, :created_at, :updated_at ],
          :include => { :posts => { :only => [:body],
                                    :include => { :attachments => { :only => [:content_file_name] } }
                                  },
                        :forum => { :only => [:forum_category_id, :forum_visibility],
                                    :include => { :customer_forums => { :only => [:customer_id] } }
                                  }
                      }
       ).to_json
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
    account.agents_from_cache.reject{ |a| user_ids.include? a.user_id }
  end
  
  def assign_default_stamps
    if forum && !stamp_type_changed?
      self.stamp_type = Topic::DEFAULT_STAMPS_BY_FORUM_TYPE[self.forum.reload.forum_type]
    end
  end
end
