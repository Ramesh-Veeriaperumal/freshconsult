class PortalSolutionCategory < ActiveRecord::Base

	belongs_to_account
	belongs_to :portal
	belongs_to :solution_category, :class_name => 'Solution::Category'

	acts_as_list :scope => :portal

	delegate :name, :to => :solution_category
end