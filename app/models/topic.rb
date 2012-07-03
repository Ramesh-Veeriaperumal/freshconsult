class Topic < ActiveRecord::Base
  include Juixe::Acts::Voteable
  acts_as_voteable 
  validates_presence_of :forum, :user, :title
  before_create  :set_default_replied_at_and_sticky
  before_update  :check_for_changing_forums
  after_save     :update_forum_counter_cache
  before_destroy :update_post_user_counts
  after_destroy  :update_forum_counter_cache

  belongs_to :forum
  belongs_to :user
  belongs_to :last_post, :class_name => "Post", :foreign_key => 'last_post_id'
  has_many :monitorships,:dependent => :destroy
  has_many :monitors, :through => :monitorships, :conditions => ["#{Monitorship.table_name}.active = ?", true], :source => :user

  has_many :posts,     :order => "#{Post.table_name}.created_at", :dependent => :destroy
  has_one  :recent_post, :order => "#{Post.table_name}.created_at DESC", :class_name => 'Post'
  
  has_one :ticket_topic,:dependent => :destroy
  has_one :ticket,:through => :ticket_topic
  
  has_many :voices, :through => :posts, :source => :user, :uniq => true
  belongs_to :replied_by_user, :foreign_key => "replied_by", :class_name => "User"
  named_scope :newest, lambda { |num| { :limit => num, :order => 'replied_at DESC' } }
  
  #Sphinx configuration starts
  define_index do
    indexes :title, :sortable => true
    indexes posts.body, :as => :comment

    has account_id, user_id
    has forum.forum_category_id, :as => :category_id
    has forum.forum_visibility, :as => :visibility
    has '0', :as => :deleted, :type => :boolean
    has '2' , :as => :status , :type => :integer

    set_property :delta => :delayed
    set_property :field_weights => {
      :title    => 10,
      :comment  => 4
    }
  end
  #Sphinx configuration ends here..

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
  attr_accessor :body_html
  
  IDEAS_STAMPS = [
    [ :planned,      I18n.t("topic.ideas_stamps.planned"),       1 ], 
    [ :implemented,  I18n.t("topic.ideas_stamps.implemented"),   2 ],
    [ :nottaken,     I18n.t("topic.ideas_stamps.nottaken"),      3 ]
  ]

  IDEAS_STAMPS_OPTIONS = IDEAS_STAMPS.map { |i| [i[1], i[2]] }
  IDEAS_STAMPS_BY_KEY = Hash[*IDEAS_STAMPS.map { |i| [i[2], i[1]] }.flatten]
  IDEAS_STAMPS_BY_TOKEN = Hash[*IDEAS_STAMPS.map { |i| [i[0], i[2]] }.flatten]
  
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

	def hit!
    self.class.increment_counter :hits, id
  end

  def sticky?() sticky == 1 end

  def views() hits end

  def paged?() posts_count > Post.per_page end
  
  def last_page
    [(posts_count.to_f / Post.per_page).ceil.to_i, 1].max
  end

  def editable_by?(user)
    user && (user.id == user_id || user.admin? || user.moderator_of?(forum_id))
  end
  
  def update_cached_post_fields(post)
    # these fields are not accessible to mass assignment
    remaining_post = post.frozen? ? recent_post : post
    if remaining_post
      self.class.update_all(['replied_at = ?, replied_by = ?, last_post_id = ?, posts_count = ?', 
        remaining_post.created_at, remaining_post.user_id, remaining_post.id, posts.count], ['id = ?', id])
    else
      self.destroy
    end
  end
  
  def users_who_voted
    users = User.find(:all,
      :joins => [:votes],
      :conditions => ["votes.voteable_id = ? and users.account_id = ?", id, account_id],
      :order => "votes.created_at DESC"
    )
    users
  end
  
  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:include => options[:include],:except => [:account_id,:import_id]) 
  end

  protected
    def set_default_replied_at_and_sticky
      self.replied_at = Time.now.utc
      self.sticky   ||= 0
    end

    def set_post_forum_id
      Post.update_all ['forum_id = ?', forum_id], ['topic_id = ?', id]
    end

    def check_for_changing_forums
      old = Topic.find(id)
      @old_forum_id = old.forum_id if old.forum_id != forum_id
      true
    end
    
    # using count isn't ideal but it gives us correct caches each time
    def update_forum_counter_cache
      forum_conditions = ['topics_count = ?', Topic.count(:id, :conditions => {:forum_id => forum_id})]
      # if the topic moved forums
      if !frozen? && @old_forum_id && @old_forum_id != forum_id
        set_post_forum_id
        Forum.update_all ['topics_count = ?, posts_count = ?', 
          Topic.count(:id, :conditions => {:forum_id => @old_forum_id}),
          Post.count(:id,  :conditions => {:forum_id => @old_forum_id})], ['id = ?', @old_forum_id]
      end
      # if the topic moved forums or was deleted
      if frozen? || (@old_forum_id && @old_forum_id != forum_id)
        forum_conditions.first << ", posts_count = ?"
        forum_conditions       << Post.count(:id, :conditions => {:forum_id => forum_id})
      end
      # User doesn't have update_posts_count method in SB2, as reported by Ryan
      # @voices.each &:update_posts_count if @voices
      Forum.update_all forum_conditions, ['id = ?', forum_id]
      @old_forum_id = @voices = nil
    end

    def update_post_user_counts
      @voices = voices.to_a
  end

end
