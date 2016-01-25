class Solution::Folder < ActiveRecord::Base

  self.primary_key = :id
  include Solution::Constants
  include Cache::Memcache::Mobihelp::Solution

  concerned_with :associations

  CACHEABLE_ATTRS = ["is_default","name","id","article_count"]
  attr_protected :category_id, :account_id
  validates_presence_of :name

  validates_uniqueness_of :name, 
    :scope => :category_id, 
    :case_sensitive => false

  self.table_name =  "solution_folders"
  
  before_update :clear_customer_folders, :backup_folder_changes

  before_save :backup_category
  before_destroy :backup_category, :add_activity_delete

  after_commit :update_search_index, on: :update, :if => :visibility_updated?
  after_commit :set_mobihelp_solution_updated_time
  
  after_create :clear_cache, :add_activity_new
  after_destroy :clear_cache
  after_update :clear_cache_with_condition
  
  has_many :customers, :through => :customer_folders

  validate :companies_limit_check
  
  scope :alphabetical, :order => 'name ASC'

  attr_accessible :name, :description, :category_id, :import_id, :visibility, :position, :is_default, :customer_folders_attributes
  attr_accessor :count_articles
  
  acts_as_list :scope => :category
  
  validates_inclusion_of :visibility, 
      :in => VISIBILITY_KEYS_BY_TOKEN.values.min..VISIBILITY_KEYS_BY_TOKEN.values.max

  include Solution::MetaMethods
  include Solution::LanguageMethods

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
    SearchSidekiq::IndexUpdate::FolderArticles.perform_async({ :folder_id => id }) if ES_ENABLED
  end

  def add_visibility(visibility, customer_ids, add_to_existing)
    add_companies(customer_ids, add_to_existing) if visibility == Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users]
    self.visibility = visibility
    save
  end

  def as_cache
    (CACHEABLE_ATTRS.inject({}) do |res, attribute|
      res.merge({ attribute => self.send(attribute) })
    end).with_indifferent_access
  end

  def visible_in? portal
    category.portal_ids.include?(portal.id)
  end

  def companies_limit_check
    if customer_folders.size > 250
      errors.add(:base, I18n.t("solution.folders.visibility.companies_limit_exceeded"))
      return false
    else
      return true
    end
  end

  private

    def populate_account
      self.account = category.account
    end

    def backup_folder_changes
      @all_changes = self.changes.clone
    end

    def backup_category
      @category_obj = category
    end

    def visibility_updated?
      @all_changes.has_key?(:visibility)
    end
    
    def set_mobihelp_solution_updated_time
      @category_obj.update_mh_solutions_category_time
    end
    
    def clear_cache
      account.clear_solution_categories_from_cache
    end
    
    def clear_cache_with_condition
      account.clear_solution_categories_from_cache unless (self.changes.keys & ['name', 'category_id', 'position']).empty?
    end

    def add_companies(customer_ids, add_to_existing)
      customer_folders.destroy_all unless add_to_existing
      customer_ids.each do |cust_id|
        customer_folders.build({:customer_id => cust_id}) unless self.customer_ids.include?(cust_id)
      end
    end

    def add_activity_delete
      create_activity('delete_folder')
    end

    def add_activity_new
      create_activity('new_folder')
    end
  
    def create_activity(type)
      activities.create(
        :description => "activities.solutions.#{type}.long",
        :short_descr => "activities.solutions.#{type}.short",
        :account    => account,
        :user       => User.current,
        :activity_data  => {
                    :path => Rails.application.routes.url_helpers.solution_folder_path(self),
                    'category_name' => h(category.name.to_s),
                    :url_params => {
                              :id => id,
                              :path_generator => 'solution_folder_path'
                            },
                    :title => name.to_s
                  }
      )
    end
end
