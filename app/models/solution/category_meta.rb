class Solution::CategoryMeta < ActiveRecord::Base

	self.primary_key = :id
	self.table_name = 'solution_category_meta'

	BINARIZE_COLUMNS = [:available]

	include Mobihelp::AppSolutionsUtils
	include Solution::LanguageAssociations
	include Solution::Constants
	include Solution::ApiDelegator

	belongs_to_account

	has_many :solution_folder_meta, 
		:class_name => "Solution::FolderMeta", 
		:foreign_key => :solution_category_meta_id, 
		:order => 'solution_folder_meta.position', 
		:dependent => :destroy

	has_many :solution_folders, :through => :solution_folder_meta

	has_many :solution_categories, 
		:inverse_of => :solution_category_meta, 
		:class_name => "Solution::Category", 
		:foreign_key => "parent_id", 
		:autosave => true, 
		:dependent => :destroy

	has_many :solution_article_meta, 
		:through => :solution_folder_meta,
		:class_name => "Solution::ArticleMeta"

	has_many :portal_solution_categories, 
		:class_name => 'PortalSolutionCategory',
		:foreign_key => :solution_category_meta_id,
		:dependent => :delete_all

	has_many :portals, 
		:through => :portal_solution_categories,
		:class_name => "Portal",
    :after_add => :clear_cache,
    :after_remove => :clear_cache

	has_many :mobihelp_app_solutions,
		:class_name => 'Mobihelp::AppSolution',
		:foreign_key => :solution_category_meta_id,
		:dependent => :destroy

	has_many :mobihelp_apps,
		:through => :mobihelp_app_solutions,
		:class_name => 'Mobihelp::App',
		:source => :app

	has_many :solution_folder_meta,
		:order => "`solution_folder_meta`.position",
		:class_name => "Solution::FolderMeta",
		:foreign_key => :solution_category_meta_id,
		:dependent => :destroy

	has_many :public_folder_meta,
		:conditions => ["`solution_folder_meta`.visibility = ? ",VISIBILITY_KEYS_BY_TOKEN[:anyone]],
		:order => "`solution_folder_meta`.position",
		:class_name =>'Solution::FolderMeta',
		:foreign_key => :solution_category_meta_id
		

	COMMON_ATTRIBUTES = ["position", "is_default", "created_at"]
	CACHEABLE_ATTRIBUTES = ["id","name","account_id","position","is_default"]

	before_create :set_default_portal
	before_save :validate_is_default

	after_create :clear_cache
	after_destroy :clear_cache

	alias_method :children, :solution_categories
	
	scope :customer_categories, {:conditions => {:is_default=>false}}

	def as_cache
	  (CACHEABLE_ATTRIBUTES.inject({}) do |res, attribute|
	    res.merge({ attribute => self.send(attribute) })
	  end).with_indifferent_access
	end
	
	def to_liquid
		@solution_category_drop ||= (Solution::CategoryDrop.new self)
	end

	private

	def clear_cache(args = nil)
		Account.current.clear_solution_categories_from_cache
	end

	def set_default_portal
	  self.portal_ids = [Account.current.main_portal.id] if self.portal_ids.blank?
	end

  def validate_is_default
    if changes[:is_default].present? || (new_record? && (is_default == true))
      default_category = Account.current.solution_category_meta.where(:is_default => true).first
      return true unless default_category.present?
      self.is_default = default_category.id == id
    end
  end
end
