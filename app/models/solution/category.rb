# require Rails.root+'/app/models/solution/folder.rb'
#In the gamification environment, Solution::Folder::VISIBILITY_KEYS_BY_TOKEN was not
#accessible. It may be due to some screw up with the order of class loading.
#So, temporarily put the 'require' here. Shan

class Solution::Category < ActiveRecord::Base

  self.primary_key = :id
  include Solution::Constants
  include Cache::Memcache::Mobihelp::Solution
  include Mobihelp::AppSolutionsUtils

  concerned_with :associations, :meta_associations
  
  self.table_name =  "solution_categories"
  
  validates_presence_of :name,:account
  validates_uniqueness_of :name, :scope => :account_id, :case_sensitive => false

  after_create :assign_portal
  
  after_save    :set_mobihelp_solution_updated_time
  before_destroy :set_mobihelp_app_updated_time

  attr_accessible :name, :description, :import_id, :is_default, :portal_ids, :position
  
  acts_as_list :scope => :account

  scope :customer_categories, {:conditions => {:is_default=>false}}

  include Solution::MetaMethods
  include Solution::LanguageMethods
  include Solution::MetaAssociationSwitcher### MULTILINGUAL SOLUTIONS - META READ HACK!!

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
    ### MULTILINGUAL SOLUTIONS - META READ HACK!! - Need to verify once
    portal_solution_category = self.portal_solution_categories.build(:solution_category_id => self.id)
    portal_solution_category.portal_id = account.main_portal.id
    portal_solution_category.save
  end

  ### MULTILINGUAL SOLUTIONS - META READ HACK!!
  def portal_ids
    account.launched?(:meta_read) ? portals_through_metum_ids : super
  end
   
  private 

    def set_mobihelp_solution_updated_time
      update_mh_solutions_category_time(self.id)
    end

    def set_mobihelp_app_updated_time
      update_mh_app_time(self.id)
    end

end
