class Solution::FolderMeta < ActiveRecord::Base

	self.primary_key = :id

	self.table_name = "solution_folder_meta"

	BINARIZE_COLUMNS = [:available]
	
  include Solution::Constants
	include Solution::LanguageAssociations
	include Solution::ApiDelegator
	
  attr_accessible :visibility, :position, :solution_category_meta_id

	belongs_to_account

  validates_inclusion_of :visibility, 
      :in => VISIBILITY_KEYS_BY_TOKEN.values.min..VISIBILITY_KEYS_BY_TOKEN.values.max

  validate :name_uniqueness, :if => "changes[:solution_category_meta_id]" 

	belongs_to :solution_category_meta, :class_name => 'Solution::CategoryMeta', :autosave => true

	has_many :solution_folders, 
		:inverse_of => :solution_folder_meta,
		:class_name => "Solution::Folder", 
		:foreign_key => "parent_id", 
		:autosave => true, 
		:dependent => :destroy

	has_many :customer_folders , 
		:class_name => 'Solution::CustomerFolder' , 
		:autosave => true,
		:dependent => :destroy

	has_many :customers, :through => :customer_folders

	has_many :solution_article_meta,
		:order => :"solution_article_meta.position",
		:class_name => "Solution::ArticleMeta",
		:foreign_key => :solution_folder_meta_id,
		:dependent => :destroy

	has_many :solution_articles,
		:through => :solution_article_meta,
		:order => :"solution_article_meta.position",
		:class_name => "Solution::Article"
		
	has_many :published_article_meta, 
 		:conditions => "`solution_articles`.status = 
			#{Solution::Article::STATUS_KEYS_BY_TOKEN[:published]}",
		:order => "`solution_article_meta`.position",
		:class_name =>'Solution::ArticleMeta',
		:foreign_key => :solution_folder_meta_id

	has_many :published_articles,
		:conditions => proc {%{`solution_articles`.status = 
			#{Solution::Article::STATUS_KEYS_BY_TOKEN[:published]} AND 
			`solution_articles`.language_id = #{Language.for_current_account.id}} },
		:through => :solution_article_meta,
		:class_name => "Solution::Article",
		:source => :solution_articles


	acts_as_list :scope => :solution_category_meta

	COMMON_ATTRIBUTES = ["visibility", "position", "is_default", "created_at"]
	CACHEABLE_ATTRIBUTES  = ["is_default","name","id","article_count"]

	before_update :clear_customer_folders, :backup_folder_changes
	after_commit :update_search_index, on: :update, :if => :update_es?
	after_commit :set_mobihelp_solution_updated_time, :if => :valid_change?
  
  after_commit ->(obj) { obj.send(:clear_cache) }, on: :create
  after_commit ->(obj) { obj.send(:clear_cache) }, on: :destroy
  after_commit ->(obj) { obj.send(:clear_cache_with_condition) }, on: :update

	before_save :backup_category
	before_destroy :backup_category

	validate :companies_limit_check

	alias_method :children, :solution_folders

	def article_count
	  solution_article_meta.size
	end

	def as_cache
	  (CACHEABLE_ATTRIBUTES.inject({}) do |res, attribute|
	    res.merge({ attribute => self.send(attribute) })
	  end).with_indifferent_access
	end

	def visibility_type
	  VISIBILITY_NAMES_BY_KEY[self.visibility]
	end

  def customer_folders_attributes=(cust_attr)
    return if cust_attr.nil?
    customer_folders.destroy_all
    company_ids = cust_attr.kind_of?(Array) ? cust_attr : cust_attr[:customer_id]
    company_ids.each do |cust_id|
      customer_folders.build({:customer_id =>cust_id})
    end
  end

	def add_visibility(visibility, customer_ids, add_to_existing)
    add_companies(customer_ids, add_to_existing) if visibility == Solution::FolderMeta::VISIBILITY_KEYS_BY_TOKEN[:company_users]
    self.visibility = visibility
    save
  end

  def has_company_visiblity?
    visibility == VISIBILITY_KEYS_BY_TOKEN[:company_users]
  end
	
	def to_liquid
		@solution_folder_drop ||= Solution::FolderDrop.new self
	end

	def update_search_index
	  SearchSidekiq::IndexUpdate::FolderArticles.perform_async({ :folder_id => id }) if ES_ENABLED

	  SearchV2::IndexOperations::UpdateArticleFolder.perform_async({ :folder_id => id }) if Account.current.features_included?(:es_v2_writes)
	end

	def clear_customer_folders
	  customer_folders.destroy_all if (visibility_changed? and visibility_was == VISIBILITY_KEYS_BY_TOKEN[:company_users])
	end
  
	def visible?(user)
	  return true if (user and user.privilege?(:view_solutions))
	  return true if self.visibility == VISIBILITY_KEYS_BY_TOKEN[:anyone]
	  return false unless user
	  return true if self.visibility == VISIBILITY_KEYS_BY_TOKEN[:logged_users]
      company_cdn = user.contractor? ? (user.company_ids & customer_folders.map(&:customer_id)).any? : 
                     (user.company  && customer_folders.map(&:customer_id).include?(user.company.id))
      return true if ((self.visibility == VISIBILITY_KEYS_BY_TOKEN[:company_users]) && company_cdn)
	end

	private

	def clear_cache
		Account.current.clear_solution_categories_from_cache
	end

	def clear_cache_with_condition
		clear_cache unless (previous_changes.keys & ['solution_category_meta_id', 'position']).empty?
	end

  def add_companies(customer_ids, add_to_existing)
    customer_folders.destroy_all unless add_to_existing
    customer_ids.each do |cust_id|
      customer_folders.build({:customer_id => cust_id}) unless self.customer_ids.include?(cust_id)
    end
  end

  def name_uniqueness
  	self.solution_folders.each do |f|
  		f.name_uniqueness_validation
  		if f.errors[:name].any?
  			errors.add(:name, I18n.t("activerecord.errors.messages.taken"))
  			break
  		end
  	end
  end

  def companies_limit_check
    if customer_folders.size > COMPANIES_LIMIT
      errors.add(:base, I18n.t("solution.folders.visibility.companies_limit_exceeded"))
      return false
    else
      return true
    end
  end

	scope :visible, lambda {|user|
		{
			:order => "`solution_folder_meta`.position",
			:conditions => visibility_condition(user)
		}
	}

	def self.visibility_condition(user)
		condition = "`solution_folder_meta`.visibility IN (#{ self.get_visibility_array(user).join(',') })"
		if (user && user.has_company?)
			condition +=  "OR (`solution_folder_meta`.visibility=#{VISIBILITY_KEYS_BY_TOKEN[:company_users]} " <<
					"AND `solution_folder_meta`.id in (SELECT solution_customer_folders.folder_meta_id " <<
					"FROM solution_customer_folders " <<
					"WHERE solution_customer_folders.customer_id in (#{user.company_ids_str}) " <<
					"AND solution_customer_folders.account_id = #{user.account_id}))"
		end
					# solution_customer_folders.customer_id = #{ user.company_id})" if (user && user.has_company?)
		return condition
	end

	def self.get_visibility_array(user)
		if user && user.privilege?(:manage_tickets)
		  VISIBILITY_NAMES_BY_KEY.keys
		elsif user
		  [VISIBILITY_KEYS_BY_TOKEN[:anyone],VISIBILITY_KEYS_BY_TOKEN[:logged_users]]
		else
		  [VISIBILITY_KEYS_BY_TOKEN[:anyone]]
		end
	end

	def visible_in? portal
	  solution_category_meta.portal_ids.include?(portal.id)
	end

	def backup_folder_changes
	  @all_changes = self.changes.clone
	end

	def update_es?
	  (@all_changes.keys & ["visibility", "solution_category_meta_id"]).present?
	end
	
	def backup_category
		@category_obj = solution_category_meta
	end
	
	def set_mobihelp_solution_updated_time
		@category_obj.update_mh_solutions_category_time
	end
	
	def valid_change?
		return true if transaction_include_action?(:destroy)
		(previous_changes.except(*(BINARIZE_COLUMNS + [:updated_at])).present? || 
			(primary_folder && primary_folder.previous_changes.present?))
	end
end
