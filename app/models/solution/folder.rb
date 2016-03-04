class Solution::Folder < ActiveRecord::Base

  self.primary_key = :id
  include Solution::Constants
  include Cache::Memcache::Mobihelp::Solution
  include Solution::Activities

  concerned_with :associations

  attr_protected :category_id, :account_id
  validates_presence_of :name
  validates_uniqueness_of :language_id, :scope => [:account_id , :parent_id], :if => "!solution_folder_meta.new_record?"

  validate :name_uniqueness_validation, :if => "new_record? || name_changed?"

  self.table_name =  "solution_folders"
  
  before_update :clear_customer_folders, :backup_folder_changes

  before_save :backup_category
  before_destroy :backup_category

  after_commit :update_search_index, on: :update, :if => :visibility_updated?
  after_commit :set_mobihelp_solution_updated_time, :if => Proc.new { |f| f.primary? }
  
  after_update :clear_cache, :if => Proc.new { |f| f.name_changed? && f.primary? }
  
  has_many :customers, :through => :customer_folders

  alias_method :parent, :solution_folder_meta
  
  scope :alphabetical, :order => 'name ASC'

  attr_accessible :name, :description, :category_id, :import_id, :visibility, :position, :is_default, :customer_folders_attributes
  attr_accessor :count_articles

  delegate :visible?, :to => :solution_folder_meta
  delegate :visible_in?, :to => :solution_folder_meta

  include Solution::MetaMethods
  include Solution::LanguageMethods
  
  SELECT_ATTRIBUTES = ["id"]

  def to_s
    name
  end

  def self.folders_for_category category_id    
    self.find_by_category_id(category_id)    
  end
  
  def article_count
    self.count_articles ||= articles.size
  end

  def visibility_type
    VISIBILITY_NAMES_BY_KEY[self.visibility]
  end

  def self.find_all_folders(account)
    self.where({ :account_id => account })
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
  
  scope :visible, lambda { |user| 
    {
      :order => "position",
      :conditions => visibility_condition(user)
    }
  }
    
  # scope :visible, lambda {|user| {
  #                   :order => "position" ,
  #                   # :joins => "LEFT JOIN `solution_customer_folders` ON 
  #                               # solution_customer_folders.folder_id = solution_folders.id and  
  #                               # solution_customer_folders.account_id = solution_folders.account_id",
  #                   :conditions => visiblity_condition(user) } }

  def self.visibility_condition(user)
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
    return unless cust_attr.present?
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

  def update_search_index
    SearchSidekiq::IndexUpdate::FolderArticles.perform_async({ :folder_id => id }) if ES_ENABLED
  end

  def add_visibility(visibility, customer_ids, add_to_existing)
    add_companies(customer_ids, add_to_existing) if visibility == Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users]
    self.visibility = visibility
    save
  end

  def primary?
    (language_id == Language.for_current_account.id)
  end

  def available?
    present?
  end

  def stripped_name
    (name || "").downcase.strip
  end

  def name_uniqueness_validation
    if ((self.solution_folder_meta.solution_category_meta.solution_folders.where(:language_id => self.language_id)) - [self]).map(&:stripped_name).include?(self.stripped_name)
      errors.add(:name, I18n.t("activerecord.errors.messages.taken"))
      return false
    end
    return true
  end

  def to_param
    parent_id
  end

  private

    def populate_account
      self.account = category.account
    end

    def backup_folder_changes
      @all_changes = self.changes.clone
    end

    def backup_category
      @category_obj = solution_category_meta
    end

    def visibility_updated?
      @all_changes.has_key?(:visibility)
    end
    
    def set_mobihelp_solution_updated_time
      @category_obj.update_mh_solutions_category_time
    end
    
    def clear_cache
      Account.current.clear_solution_categories_from_cache
    end

    def add_companies(customer_ids, add_to_existing)
      customer_folders.destroy_all unless add_to_existing
      customer_ids.each do |cust_id|
        customer_folders.build({:customer_id => cust_id}) unless self.customer_ids.include?(cust_id)
      end
    end
end
