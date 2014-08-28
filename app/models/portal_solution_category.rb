class PortalSolutionCategory < ActiveRecord::Base

	belongs_to_account
	belongs_to :portal
	belongs_to :solution_category, :class_name => 'Solution::Category'
  attr_accessible :portal_id, :solution_category_id, :account_id
	acts_as_list :scope => :portal

	delegate :name, :to => :solution_category
end