class Solution::Folder < ActiveRecord::Base

  self.primary_key = :id
  include Solution::Constants
  include Cache::Memcache::Mobihelp::Solution
  include Mobihelp::AppSolutionsUtils

  concerned_with :associations, :meta_associations

  attr_protected :category_id, :account_id
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :category_id, :case_sensitive => false

  self.table_name =  "solution_folders"
  
  # before_create :populate_account
  before_update :clear_customer_folders, :backup_folder_changes

  after_commit :update_search_index, on: :update, :if => :visibility_updated?
  after_commit :set_mobihelp_solution_updated_time
  
  scope :alphabetical, :order => 'name ASC'

  attr_accessible :name, :description, :category_id, :import_id, :visibility, :position, :is_default, :customer_folders_attributes
  
  acts_as_list :scope => :category
  
  validates_inclusion_of :visibility, :in => VISIBILITY_KEYS_BY_TOKEN.values.min..VISIBILITY_KEYS_BY_TOKEN.values.max

  include Solution::MetaMethods
  include Solution::LanguageMethods

  def self.folders_for_category category_id    
    self.find_by_category_id(category_id)    
  end

  def self.find_all_folders(account)   
    self.find(:all).select { |a| a.account_id.eql?(account) }
  end

  def visible?(user)    
    return true if (user and user.privilege?(:manage_tickets) )
    return true if self.visibility == VISIBILITY_KEYS_BY_TOKEN[:anyone]
    return true if (user and (self.visibility == VISIBILITY_KEYS_BY_TOKEN[:logged_users]))
    return true if (user && (self.visibility == VISIBILITY_KEYS_BY_TOKEN[:company_users]) && user.company  && customer_folders.map(&:customer_id).include?(user.company.id))
  end
  
  def self.get_visibility_array(user)   
    vis_arr = Array.new
    if user && user.privilege?(:manage_tickets)
      vis_arr = VISIBILITY_NAMES_BY_KEY.keys
    elsif user
      vis_arr = [VISIBILITY_KEYS_BY_TOKEN[:anyone],VISIBILITY_KEYS_BY_TOKEN[:logged_users]]
    else
      vis_arr = [VISIBILITY_KEYS_BY_TOKEN[:anyone]]   
    end
  end
  
  scope :visible, lambda {|user| {
                    :order => "position" ,
                    # :joins => "LEFT JOIN `solution_customer_folders` ON 
                                # solution_customer_folders.folder_id = solution_folders.id and  
                                # solution_customer_folders.account_id = solution_folders.account_id",
                    :conditions => visiblity_condition(user) } }


  def self.visiblity_condition(user)
    condition = "solution_folders.visibility IN (#{ self.get_visibility_array(user).join(',') })"
    condition +=   " OR 
            (solution_folders.visibility=#{VISIBILITY_KEYS_BY_TOKEN[:company_users]} AND 
              solution_folders.id in (SELECT solution_customer_folders.folder_id 
                                        FROM solution_customer_folders WHERE 
                                        solution_customer_folders.customer_id =
                                         #{user.company_id} AND 
                                         solution_customer_folders.account_id = 
                                         #{user.account_id}))" if (user && user.has_company?)
                # solution_customer_folders.customer_id = #{ user.company_id})" if (user && user.has_company?)

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
  
  def has_company_visiblity?
    visibility == VISIBILITY_KEYS_BY_TOKEN[:company_users]
  end
  
  def to_xml(options = {})
     options[:root] = 'solution_folder'# TODO-RAILS3
     options[:indent] ||= 2
      xml = options[:builder] ||= ::Builder::XmlMarkup.new(:indent => options[:indent])
      xml.instruct! unless options[:skip_instruct]
      super(:builder => xml, :skip_instruct => true,:include => options[:include],:except => [:account_id,:import_id], :root => options[:root] ) 
  end

  def as_json(options={})
    options[:except] = [:account_id,:import_id]
    super options
  end

  def to_liquid
    @solution_folder_drop ||= Solution::FolderDrop.new self
  end

  def update_search_index
    Resque.enqueue(Search::IndexUpdate::FolderArticles, { :current_account_id => account_id, :folder_id => id })
  end

  private

    def populate_account
      self.account = category.account
    end

    def backup_folder_changes
      @all_changes = self.changes.clone
    end

    def visibility_updated?
      @all_changes.has_key?(:visibility)
    end
    
    def set_mobihelp_solution_updated_time
      update_mh_solutions_category_time(self.category_id)
    end

end
