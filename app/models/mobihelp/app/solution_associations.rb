class Mobihelp::App < ActiveRecord::Base

	FEATURE_BASED_METHODS = [:solution_categories]

	has_many :app_solutions, :class_name => 'Mobihelp::AppSolution', :dependent => :destroy

	has_many :solution_categories, :class_name => 'Solution::Category', :through => :app_solutions
	
	has_many :solution_category_meta, :class_name => 'Solution::CategoryMeta', :through => :app_solutions

	has_many :solution_categories_through_meta, 
		:class_name => 'Solution::Category', 
		:through => :solution_category_meta,
		:source => :solution_categories

	include Solution::MetaAssociationSwitcher
end