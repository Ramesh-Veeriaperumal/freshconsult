class Solution::Folder < ActiveRecord::Base
  
  attr_protected :category_id, :account_id
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :category_id
  
  belongs_to_account
  belongs_to :category, :class_name => 'Solution::Category'
  set_table_name "solution_folders"
  
  acts_as_list :scope => :category
  
  before_create :populate_account
  after_save :set_article_delta_flag
  before_update :clear_customer_folders
  
  has_many :articles, :class_name =>'Solution::Article', :dependent => :destroy, :order => "position"
  has_many :published_articles, :class_name =>'Solution::Article', :order => "position",
           :conditions => "solution_articles.status = #{Solution::Article::STATUS_KEYS_BY_TOKEN[:published]}"

  has_many :customer_folders , :class_name => 'Solution::CustomerFolder' , :dependent => :destroy
  
  named_scope :alphabetical, :order => 'name ASC'

  attr_protected :account_id
  
  VISIBILITY = [
  [ :anyone,       I18n.t("solutions.visibility.all"),          1 ], 
  [ :logged_users, I18n.t("solutions.visibility.logged_in_users"), 2 ],
  [ :agents,       I18n.t("solutions.visibility.agents"),          3 ],
  [ :company_users ,I18n.t("solutions.visibility.select_company") , 4]
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
    return true if (user and user.has_manage_solutions? )
    return true if self.visibility == VISIBILITY_KEYS_BY_TOKEN[:anyone]
    return true if (user and (self.visibility == VISIBILITY_KEYS_BY_TOKEN[:logged_users]))
    return true if (user && (self.visibility == VISIBILITY_KEYS_BY_TOKEN[:company_users]) && user.customer  && customer_folders.map(&:customer_id).include?(user.customer.id))
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
  
  named_scope :visible, lambda {|user| {
                    :order => "position",
                    :joins => "LEFT JOIN `solution_customer_folders` ON 
                                solution_customer_folders.folder_id = solution_folders.id and  
                                solution_customer_folders.account_id = solution_folders.account_id",
                    :conditions => visiblity_condition(user) } }


  def self.visiblity_condition(user)
    condition =   { :visibility => self.get_visibility_array(user) }
    condition =  Solution::Folder.merge_conditions(condition) + " OR(solution_folders.visibility=#{VISIBILITY_KEYS_BY_TOKEN[:company_users]} AND 
                solution_customer_folders.customer_id = #{ user.customer_id})" if (user && user.has_company?)
    return condition
  end

  def customer_folders_attributes=(cust_attr)
    customer_folders.destroy_all
    cust_attr[:customer_id].each do |cust_id|
      customer_folders.build({:customer_id =>cust_id})
    end
  end

  def clear_customer_folders
      customer_folders.destroy_all if (visibility_changed? and visibility_was == VISIBILITY_KEYS_BY_TOKEN[:company_users])
  end
  
  def set_article_delta_flag
    self.articles.each do |article|
      article.delta = true
      article.save
    end
  end

  def has_company_visiblity?
    visibility == VISIBILITY_KEYS_BY_TOKEN[:company_users]
  end
  
  def to_xml(options = {})
     options[:indent] ||= 2
      xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:include => options[:include],:except => [:account_id,:import_id]) 
  end

  def to_liquid
    @solution_folder_drop ||= Solution::FolderDrop.new self
  end

  private
    def populate_account
      self.account = category.account
    end
  
end
