class Mobihelp::App < ActiveRecord::Base

	has_many :app_solutions, :class_name => 'Mobihelp::AppSolution', :dependent => :destroy

	has_many :solution_categories, :class_name => 'Solution::Category', :through => :app_solutions, :order => "`mobihelp_app_solutions`.`position`"
	
	has_many :solution_category_meta, :class_name => 'Solution::CategoryMeta', :through => :app_solutions
end