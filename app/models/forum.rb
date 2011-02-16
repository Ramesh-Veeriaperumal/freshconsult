class Forum < ActiveRecord::Base
  acts_as_list

  validates_presence_of :name,:forum_category
  
  belongs_to :forum_category

  has_many :moderatorships, :dependent => :destroy
  has_many :moderators, :through => :moderatorships, :source => :user

  has_many :topics, :order => 'sticky desc, replied_at desc', :dependent => :delete_all
  has_one  :recent_topic, :class_name => 'Topic', :order => 'sticky desc, replied_at desc'

  # this is used to see if a forum is "fresh"... we can't use topics because it puts
  # stickies first even if they are not the most recently modified
  has_many :recent_topics, :class_name => 'Topic', :order => 'replied_at DESC'
  has_one  :recent_topic,  :class_name => 'Topic', :order => 'replied_at DESC'

  has_many :posts,     :order => "#{Post.table_name}.created_at DESC", :dependent => :delete_all
  has_one  :recent_post, :order => "#{Post.table_name}.created_at DESC", :class_name => 'Post'
  
  format_attribute :description
  
  TYPES = [
    [ :howto,   "Questions",     1 ], 
    [ :ideas,   "Ideas",         2 ],
    [ :problem, "Problems",      3 ],
    [ :announce, "Announcement", 4 ]
  ]

  TYPE_OPTIONS = TYPES.map { |i| [i[1], i[2]] }
  TYPE_NAMES_BY_KEY = Hash[*TYPES.map { |i| [i[2], i[1]] }.flatten]
  TYPE_KEYS_BY_TOKEN = Hash[*TYPES.map { |i| [i[0], i[2]] }.flatten]
  
  def announcement?()
    forum_type == TYPE_KEYS_BY_TOKEN[:announce]
  end

  def ideas?()
    self.forum_type == 2 
  end
  
  def questions?()
    self.forum_type == 3 
  end
  
  # retrieves forums ordered by position
  def self.find_ordered(account, options = {})
    find :all, options.update(:conditions => {:account_id => account}, :order => 'position')
  end
  
  def type_name
    TYPE_NAMES_BY_KEY[forum_type]
  end
  
  
  
end
