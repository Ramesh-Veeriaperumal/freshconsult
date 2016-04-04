class Solution::CategoryMeta < ActiveRecord::Base

	self.primary_key = :id
	self.table_name = 'solution_category_meta'

	include Mobihelp::AppSolutionsUtils
	include Solution::LanguageAssociations
	include Solution::Constants
	include Solution::ApiDelegator

	belongs_to_account

	has_many :solution_folder_meta, :class_name => "Solution::FolderMeta", :foreign_key => :solution_category_meta_id, :order => :position

	has_many :solution_folders, :through => :solution_folder_meta, :order => 'solution_folder_meta.position'

	has_many :solution_categories, :class_name => "Solution::Category", :foreign_key => "parent_id", :autosave => true

	has_many :portal_solution_categories, :class_name => 'PortalSolutionCategory',
		:foreign_key => :solution_category_meta_id,
		:dependent => :delete_all

	has_many :portals, :class_name => "Portal", :through => :portal_solution_categories

	has_many :mobihelp_app_solutions,
		:class_name => 'Mobihelp::AppSolution',
		:foreign_key => :solution_category_meta_id,
		:dependent => :destroy

	has_many :mobihelp_apps,
		:class_name => 'Mobihelp::App',
		:through => :mobihelp_app_solutions,
		:source => :app

	has_many :solution_folder_meta,
		:class_name => "Solution::FolderMeta",
		:foreign_key => :solution_category_meta_id,
		:order => "`solution_folder_meta`.position",
		:dependent => :destroy

	has_many :public_folder_meta,
		:class_name =>'Solution::FolderMeta',
		:foreign_key => :solution_category_meta_id,
		:order => "`solution_folder_meta`.position",
		:conditions => ["`solution_folder_meta`.visibility = ? ",VISIBILITY_KEYS_BY_TOKEN[:anyone]]

	COMMON_ATTRIBUTES = ["position", "is_default", "created_at"]

	scope :customer_categories, {:conditions => {:is_default=>false}}

	def to_liquid
		@solution_category_meta_drop ||= (Solution::CategoryMetaDrop.new self)
	end
end
