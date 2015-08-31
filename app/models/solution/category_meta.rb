class Solution::CategoryMeta < ActiveRecord::Base

	self.primary_key = :id
	self.table_name = 'solution_category_meta'

	include Mobihelp::AppSolutionsUtils
	include Solution::MetaModelMethods

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

	COMMON_ATTRIBUTES = ["position", "is_default", "created_at"]
end