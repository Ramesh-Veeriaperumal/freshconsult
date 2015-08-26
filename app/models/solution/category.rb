# require Rails.root+'/app/models/solution/folder.rb'
#In the gamification environment, Solution::Folder::VISIBILITY_KEYS_BY_TOKEN was not
#accessible. It may be due to some screw up with the order of class loading.
#So, temporarily put the 'require' here. Shan

class Solution::Category < ActiveRecord::Base

  self.primary_key = :id
  include Solution::Constants
  include Cache::Memcache::Mobihelp::Solution
  include Mobihelp::AppSolutionsUtils
  include Solution::MetaMethods
  
  self.table_name =  "solution_categories"
  
  validates_presence_of :name,:account
  validates_uniqueness_of :name, :scope => :account_id, :case_sensitive => false
  
  after_save    :set_mobihelp_solution_updated_time
  before_destroy :set_mobihelp_app_updated_time

  concerned_with :associations, :meta_associations

  before_create :set_default_portal

  attr_accessible :name, :description, :import_id, :is_default, :portal_ids, :position
  
  acts_as_list :scope => :account

  scope :customer_categories, {:conditions => {:is_default=>false}}

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

  ### MULTILINGUAL SOLUTIONS - META READ HACK!!
  def portal_ids_with_meta
    account.launched?(:meta_read) ? portals_through_metum_ids : portal_ids_without_meta
  end

  alias_method_chain :portal_ids, :meta
   
  private 

    def set_mobihelp_solution_updated_time
      category_obj.update_mh_solutions_category_time
    end

    def set_mobihelp_app_updated_time
      category_obj.update_mh_app_time
    end

    def category_obj
      self.reload
      Account.current.launched?(:meta_read) ? self.solution_category_meta : self
    end

    ### MULTILINGUAL SOLUTIONS - META WRITE HACK!!
    def set_default_portal
      self.portal_ids = [Account.current.main_portal.id] if self.portal_ids_without_meta.blank?
    end

end
