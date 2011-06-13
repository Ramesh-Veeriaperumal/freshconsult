class ForumCategory < ActiveRecord::Base
  validates_presence_of :name,:account
  validates_uniqueness_of :name, :scope => :account_id

  has_many :forums, :dependent => :destroy
  has_many :portal_forums, :class_name => 'Forum', :conditions =>{:forum_visibility => Forum::VISIBILITY_KEYS_BY_TOKEN[:anyone]} 
  has_many :user_forums, :class_name => 'Forum', :conditions =>['forum_visibility != ?', Forum::VISIBILITY_KEYS_BY_TOKEN[:agents]] 
  has_many :portal_topics, :through => :portal_forums
  has_many :user_topics, :through => :user_forums
  
  attr_accessible :name,:description , :import_id
  belongs_to :account
  
  
   
   
   # retrieves forums ordered by position
  def self.find_ordered(account, options = {})
    find :all, options.update(:conditions => {:account_id => account}, :order => 'name')
  end
  
  
 end
