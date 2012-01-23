class Solution::Folder < ActiveRecord::Base
  
  attr_accessible  :name,:description, :visibility
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :category_id
  
  belongs_to :category, :class_name => 'Solution::Category'
  set_table_name "solution_folders"
  
  acts_as_list :scope => :category
  
  after_save :set_article_delta_flag
  
  has_many :articles, :class_name =>'Solution::Article' , :dependent => :destroy, :order => "position"
  has_many :published_articles, :class_name =>'Solution::Article' ,:order => "position",
           :conditions => "solution_articles.status = #{Solution::Article::STATUS_KEYS_BY_TOKEN[:published]}"
  
  named_scope :alphabetical, :order => 'name ASC'
  
  VISIBILITY = [
  [ :anyone,       I18n.t("solutions.visibility.anyone"),          1 ], 
  [ :logged_users, I18n.t("solutions.visibility.logged_in_users"), 2 ],
  [ :agents,       I18n.t("solutions.visibility.agents"),          3 ]
  ]
  
  VISIBILITY_OPTIONS = VISIBILITY.map { |i| [i[1], i[2]] }
  VISIBILITY_NAMES_BY_KEY = Hash[*VISIBILITY.map { |i| [i[2], i[1]] }.flatten] 
  VISIBILITY_KEYS_BY_TOKEN = Hash[*VISIBILITY.map { |i| [i[0], i[2]] }.flatten] 
  
  validates_inclusion_of :visibility, :in => VISIBILITY_KEYS_BY_TOKEN.values.min..VISIBILITY_KEYS_BY_TOKEN.values.max

  def self.folders_for_category category_id    
    self.find_by_category_id(category_id)    
  end

  def self.find_all_folders(account)   
    self.find(:all).select { |a| a.account_id.eql?(account) }
  end

  def visible?(user)    
    return true if self.visibility == VISIBILITY_KEYS_BY_TOKEN[:anyone]
    return true if (user and (self.visibility == VISIBILITY_KEYS_BY_TOKEN[:logged_users]))
    return true if (user and user.has_manage_solutions? and (self.visibility == VISIBILITY_KEYS_BY_TOKEN[:agents]) )
  end
  
  def self.get_visibility_array(user)   
    vis_arr = Array.new
    if user && user.has_manage_solutions?
      vis_arr = VISIBILITY_NAMES_BY_KEY.keys
    elsif user
      vis_arr = [VISIBILITY_KEYS_BY_TOKEN[:anyone],VISIBILITY_KEYS_BY_TOKEN[:logged_users]]
    else
      vis_arr = [VISIBILITY_KEYS_BY_TOKEN[:anyone]]   
    end
  end
  
  named_scope :visible, lambda{|user| {:conditions => {:visibility =>self.get_visibility_array(user)} }}
  
  def set_article_delta_flag
    self.articles.each do |article|
      article.delta = true
      article.save
    end
  end
  
  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:include => options[:include],:except => [:account_id,:import_id]) 
  end
  
end
