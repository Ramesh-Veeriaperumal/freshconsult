class ForumCategory < ActiveRecord::Base
  validates_presence_of :name,:account_id
  validates_uniqueness_of :name, :scope => :account_id

  has_many :forums, :dependent => :destroy, :order => "position"
  has_many :portal_forums, :class_name => 'Forum', :conditions =>{:forum_visibility => Forum::VISIBILITY_KEYS_BY_TOKEN[:anyone]} , :order => "position" 
  has_many :user_forums, :class_name => 'Forum', :conditions =>['forum_visibility != ?', Forum::VISIBILITY_KEYS_BY_TOKEN[:agents]] , :order => "position"
  has_many :portal_topics, :through => :portal_forums
  has_many :user_topics, :through => :user_forums
  
  attr_accessible :name,:description , :import_id
  belongs_to :account
  
  acts_as_list :scope => :account  
   
   
   # retrieves forums ordered by position
  def self.find_ordered(account, options = {})
    find :all, options.update(:conditions => {:account_id => account}, :order => 'name')
  end
  
  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:include => options[:include],:except => [:account_id,:import_id]) 
  end
  
  
 end
