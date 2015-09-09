class Portal < ActiveRecord::Base

	FEATURE_BASED_METHODS = [:solution_categories]

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

	has_many :solution_categories_through_meta,
		:class_name => 'Solution::Category',
		:through => :solution_category_meta,
		:source => :solution_categories,
		:order => "portal_solution_categories.position",
		:conditions => proc { "solution_categories.language_id = '#{Language.for_current_account.id}'" },
		:readonly => false

	include Solution::MetaAssociationSwitcher### MULTILINGUAL SOLUTIONS - META READ HACK!!
end