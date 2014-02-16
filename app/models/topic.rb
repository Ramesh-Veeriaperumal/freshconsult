class Topic < ActiveRecord::Base
  include Juixe::Acts::Voteable
  include Search::ElasticSearchIndex
  include ActionController::UrlWriter
  include Mobile::Actions::Topic
  acts_as_voteable 
  validates_presence_of :forum, :user, :title

  belongs_to_account
  belongs_to :forum
  belongs_to :user
  belongs_to :last_post, :class_name => "Post", :foreign_key => 'last_post_id'

  before_create :set_locked
  before_save :set_sticky

  has_many :monitorships, :as => :monitorable, :class_name => "Monitorship", :dependent => :destroy
  has_many :monitors, :through => :monitorships, :conditions => ["#{Monitorship.table_name}.active = ?", true], :source => :user

  has_many :posts, :order => "#{Post.table_name}.created_at", :dependent => :delete_all
  # previously posts had :dependant => :destroy
  # to delete all dependant post hile deleting a topic, destroy has been changed to delete all
  # as a result no callbacks will be triggered and so User.posts_count will not be updated
  has_one  :recent_post, :order => "#{Post.table_name}.created_at DESC", :class_name => 'Post'
  
  has_one :ticket_topic, :dependent => :destroy
  has_one :ticket,:through => :ticket_topic
  
  has_many :voices, :through => :posts, :source => :user, :uniq => true
  belongs_to :replied_by_user, :foreign_key => "replied_by", :class_name => "User"
  has_many :activities, 
    :class_name => 'Helpdesk::Activity', 
    :as => 'notable'

  named_scope :newest, :order => 'replied_at DESC'

  named_scope :visible, lambda {|user| visiblity_options(user) }

  named_scope :by_user, lambda { |user| { :conditions => ["user_id = ?", user.id ] } }

  named_scope :find_by_forum_category_id, lambda { |forum_category_id|
    { :joins => %(INNER JOIN forums ON forums.id = topics.forum_id AND 
        forums.account_id = topics.account_id),
      :conditions => ["forums.forum_category_id = ?", forum_category_id],
    }
  }

  # Popular topics in forums
  # Filtered based on last replied and user_votes
  # !FORUM ENHANCE Removing hits from orderby of popular as it will return all time
  # It would be better if it can be tracked month wise
  # Generally with days before DateTime.now - 30.days
  named_scope :popular, lambda { |days_before| 
    { :conditions => ["replied_at >= ?", days_before], 
      :order => 'hits DESC, user_votes DESC, replied_at DESC', 
      :include => :last_post } 
  }

  # The below named scopes are used in fetching topics with a specific stamp used for portal topic list  
  named_scope :by_stamp, lambda { |stamp_type| 
    { :conditions => ["stamp_type = ?", stamp_type] }
  }

  def self.visiblity_options(user)
    if user
       if user.privilege?(:manage_tickets)
          {}
       else
          { :include => [:forum =>:customer_forums],
            :conditions =>["forums.forum_visibility in(?) OR (forums.forum_visibility = ? and customer_forums.customer_id =?)" ,
                           Forum.visibility_array(user) , Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users] ,user.customer_id]
          }
       end
    else
      { 
        :include =>[:forum],:conditions => ["forums.forum_visibility = ?" , Forum::VISIBILITY_KEYS_BY_TOKEN[:anyone]] 
      } 
    end
  end

  named_scope :for_forum, lambda { |forum|
    { :conditions => ["forum_id = ? ", forum] 
    }
  }
  named_scope :limit, lambda { |num| { :limit => num } }  
  named_scope :freshest, lambda { |account|
    { :conditions => ["account_id = ? ", account], 
      :order => "topics.replied_at DESC"
    }
  }
  
  attr_protected :forum_id , :account_id
  # to help with the create form
  attr_accessor :body_html, :highlight_title
  
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
  IDEAS_STAMPS_TOKEN_BY_KEY = Hash[*IDEAS_STAMPS.map { |i| [i[2], i[0]] }.flatten]
  IDEAS_TOKENS = IDEAS_STAMPS.map { |i| i[0] }
  
  def monitorship_emails
    user_emails = Array.new
    for monitorship in self.monitorships.active_monitors
      user_emails = monitorships.collect {|a| a.user.email}
    end
    return user_emails.compact
  end
   
  def stamp_name
    IDEAS_STAMPS_BY_KEY[stamp_type]
  end  

  def stamp_key
    IDEAS_STAMPS_TOKEN_BY_KEY[stamp_type].to_s
  end

	def hit!
    self.class.increment_counter :hits, id
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
  
  def last_page
    [(posts_count.to_f / Post.per_page).ceil.to_i, 1].max
  end
  
  def update_cached_post_fields(post)
    # these fields are not accessible to mass assignment
    remaining_post = post.frozen? ? recent_post : post
    if remaining_post
      self.class.update_all(['replied_at = ?, replied_by = ?, last_post_id = ?, posts_count = ?', 
        remaining_post.created_at, remaining_post.user_id, remaining_post.id, posts.count], ['id = ?', id])
    # else
      # self.destroy
    end
  end

  def answered?
    posts.answered_posts.count > 0
  end
  
  def users_who_voted
    users = User.find(:all,
      :joins => [:votes],
      :conditions => ["votes.voteable_id = ? and users.account_id = ?", id, account_id],
      :order => "votes.created_at DESC"
    )
    users
  end
  
  def last_post_url
    if self.last_post_id.present?
      support_discussions_topic_path(self, :anchor => "post-#{self.last_post_id}")
    end
  end

  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:include => options[:include],:except => [:account_id,:import_id]) 
  end

  def to_indexed_json
    to_json( 
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
       )
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
    truncate(self.posts.first.body.gsub(/<\/?[^>]*>/, ""), 300)
  end

end
