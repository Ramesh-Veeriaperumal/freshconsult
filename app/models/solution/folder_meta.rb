class Solution::FolderMeta < ActiveRecord::Base

	self.primary_key = :id
  
	self.table_name = "solution_folder_meta"
  include Solution::Constants
	include Solution::LanguageAssociations
	belongs_to_account
	
  validates_inclusion_of :visibility, 
      :in => VISIBILITY_KEYS_BY_TOKEN.values.min..VISIBILITY_KEYS_BY_TOKEN.values.max

  validate :name_uniqueness

	belongs_to :solution_category_meta, :class_name => 'Solution::CategoryMeta'

	has_many :solution_folders, :class_name => "Solution::Folder", :foreign_key => "parent_id", :autosave => true, :inverse_of => :solution_folder_meta, :dependent => :destroy

	has_many :customer_folders , :class_name => 'Solution::CustomerFolder' , :dependent => :destroy

	has_many :customers, :through => :customer_folders

	has_many :solution_article_meta, :class_name => "Solution::ArticleMeta", :foreign_key => :solution_folder_meta_id, :order => :position, :dependent => :destroy

	has_many :solution_articles, 
		:class_name => "Solution::Article", 
		:through => :solution_article_meta,
		:order => :"solution_article_meta.position"

	acts_as_list :scope => :solution_category_meta

	COMMON_ATTRIBUTES = ["visibility", "position", "is_default", "created_at"]
	CACHEABLE_ATTRIBUTES  = ["is_default","name","id","article_count"]

	after_create :clear_cache
	after_destroy :clear_cache
	after_update :clear_cache_with_condition

	def article_count
	  solution_article_meta.size
	end

	def as_cache
	  (CACHEABLE_ATTRIBUTES.inject({}) do |res, attribute|
	    res.merge({ attribute => self.send(attribute) })
	  end).with_indifferent_access
	end

	def visible?(user)
	  return true if (user and user.privilege?(:view_solutions))
	  return true if self.visibility == VISIBILITY_KEYS_BY_TOKEN[:anyone]
	  return true if (user and (self.visibility == VISIBILITY_KEYS_BY_TOKEN[:logged_users]))
	  return true if (user && (self.visibility == VISIBILITY_KEYS_BY_TOKEN[:company_users]) && user.company  && customer_folders.map(&:customer_id).include?(user.company.id))
	end

	def visible_in? portal
	  solution_category_meta.portal_ids.include?(portal.id)
	end

  def customer_folders_attributes=(cust_attr)
    customer_folders.destroy_all
    customers = cust_attr.kind_of?(Array) ? cust_attr : cust_attr[:customer_id]
    customers.each do |cust_id|
      customer_folders.build({:customer_id =>cust_id})
    end
  end

	private

	def clear_cache
		account.clear_solution_categories_from_cache
	end

	def clear_cache_with_condition
		account.clear_solution_categories_from_cache unless (self.changes.keys & ['solution_category_meta_id', 'position']).empty?
	end

	def add_visibility(visibility, customer_ids, add_to_existing)
    add_companies(customer_ids, add_to_existing) if visibility == Solution::FolderMeta::VISIBILITY_KEYS_BY_TOKEN[:company_users]
    self.visibility = visibility
    save
  end

  def add_companies(customer_ids, add_to_existing)
    customer_folders.destroy_all unless add_to_existing
    customer_ids.each do |cust_id|
      customer_folders.build({:customer_id => cust_id}) unless self.customer_ids.include?(cust_id)
    end
  end

  def name_uniqueness
  	err_flag = false
  	self.solution_folders.each do |f|
  		f.name_uniqueness_validation
  		if f.errors[:name].any?
  			err_flag = true
  			break
  		end
  	end
  	errors.add(:base, I18n.t("activerecord.errors.messages.taken")) if err_flag
  end

end
