class PortalSolutionCategory < ActiveRecord::Base

  self.primary_key = :id
	belongs_to_account
	belongs_to :portal
	belongs_to :solution_category, :class_name => 'Solution::Category'
  attr_accessible :portal_id, :solution_category_id, :account_id, :position
	acts_as_list :scope => :portal

	delegate :name, :to => :solution_category
  

  after_create :clear_cache
  after_destroy :clear_cache
  after_update :clear_cache, :if => :position_changed?
  
  def position_changed?
    self.changes.key?("position")
  end

  def clear_cache
    account.clear_solution_categories_from_cache
  end

end