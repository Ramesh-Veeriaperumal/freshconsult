class Solution::CategoryMeta < ActiveRecord::Base

	self.primary_key = :id
	self.table_name = 'solution_category_meta'

	belongs_to_account

	has_many :solution_folder_meta, :class_name => "Solution::FolderMeta", :foreign_key => "solution_category_meta_id"

	has_many :solution_categories, :class_name => "Solution::Category", :foreign_key => "parent_id"

	has_many :portal_solution_categories, :class_name => 'PortalSolutionCategory', 
		:foreign_key => :solution_category_meta_id

	has_many :portals, :class_name => "Portal", :through => :portal_solution_categories

	has_many :mobihelp_app_solutions, :class_name => 'Mobihelp::AppSolution', :foreign_key => :solution_category_meta_id
		
	has_many :mobihelp_apps, :class_name => 'Mobihelp::App', :through => :mobihelp_app_solutions

	COMMON_ATTRIBUTES = ["position", "is_default", "account_id", "created_at"]

end