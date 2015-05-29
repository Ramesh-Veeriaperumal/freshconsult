class PortalSolutionCategory < ActiveRecord::Base

  self.primary_key = :id
	belongs_to_account
	belongs_to :portal
	belongs_to :solution_category, :class_name => 'Solution::Category'
	belongs_to :solution_category_meta, :class_name => 'Solution::CategoryMeta'
  attr_accessible :portal_id, :solution_category_id, :account_id, :position
	acts_as_list :scope => :portal

	delegate :name, :to => :solution_category
end