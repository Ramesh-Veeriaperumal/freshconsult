# require Rails.root+'/app/models/solution/folder.rb'
#In the gamification environment, Solution::Folder::VISIBILITY_KEYS_BY_TOKEN was not
#accessible. It may be due to some screw up with the order of class loading.
#So, temporarily put the 'require' here. Shan

class Solution::Category < ActiveRecord::Base

  self.primary_key = :id
  include Solution::Constants
  include Cache::Memcache::Mobihelp::Solution
  
  self.table_name =  "solution_categories"
  
  validates_presence_of :name,:account
  validates_uniqueness_of :name, :scope => :account_id, :case_sensitive => false
  
  belongs_to_account

  has_many :folders, :class_name =>'Solution::Folder' , :dependent => :destroy, :order => "position"
  has_many :public_folders, :class_name =>'Solution::Folder' ,  :order => "position", 
          :conditions => [" solution_folders.visibility = ? ",VISIBILITY_KEYS_BY_TOKEN[:anyone]]
  has_many :published_articles, :through => :public_folders
  has_many :articles, :through => :folders
  has_many :portal_solution_categories, 
    :class_name => 'PortalSolutionCategory', 
    :foreign_key => :solution_category_id, 
    :dependent => :delete_all

  has_many :portals, :through => :portal_solution_categories
  has_many :user_folders, :class_name =>'Solution::Folder' , :order => "position", 
          :conditions => [" solution_folders.visibility in (?,?) ",
          VISIBILITY_KEYS_BY_TOKEN[:anyone],VISIBILITY_KEYS_BY_TOKEN[:logged_users]]
   
  after_create :assign_portal
  after_destroy :clear_mobihelp_solutions_cache

  attr_accessible :name, :description, :import_id, :is_default, :portal_ids, :position
  
  acts_as_list :scope => :account

  scope :customer_categories, {:conditions => {:is_default=>false}}

  def to_xml(options = {})
     options[:root] ||= 'solution_category'
     options[:indent] ||= 2
      xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:include => options[:include],:except => [:account_id,:import_id], :root => options[:root]) 
  end
  
  def as_json(options={})
    options[:except] = [:account_id,:import_id]
    super options
  end

  def self.folder_names(account)
    account.solution_categories.map { |category| 
      [ category.name, category.folders.map {|folder| [folder.id, folder.name] } ]
    }
  end
  
  def self.get_default_categories_visibility(user)
    user.customer? ? {:is_default=>false} : {}
  end
  
  def to_liquid
    @solution_category_drop ||= (Solution::CategoryDrop.new self)
  end

  def assign_portal
    portal_solution_category = self.portal_solution_categories.build
    portal_solution_category.portal_id = account.main_portal.id
    portal_solution_category.save
  end
   
  private 

    def clear_mobihelp_solutions_cache
      clear_solutions_cache(self.id)
    end
end
