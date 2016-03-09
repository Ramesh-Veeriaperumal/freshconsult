class Portal < ActiveRecord::Base

	has_many :portal_solution_categories,
		:class_name => 'PortalSolutionCategory',
		:foreign_key => :portal_id,
		:order => "position",
		:dependent => :delete_all

	has_many :solution_category_meta,
		:class_name => 'Solution::CategoryMeta',
		:through => :portal_solution_categories,
		:order => "portal_solution_categories.position"

	has_many :solution_categories,
		:class_name => 'Solution::Category',
		:through => :portal_solution_categories,
		:order => "portal_solution_categories.position",
		:after_add => :clear_solution_cache,
		:after_remove => :clear_solution_cache
end
