class PortalSolutionCategory < ActiveRecord::Base

  self.primary_key = :id
	belongs_to_account
	belongs_to :portal
	belongs_to :solution_category, :class_name => 'Solution::Category'
	belongs_to :solution_category_meta, :class_name => 'Solution::CategoryMeta'
  attr_accessible :portal_id, :solution_category_id, :account_id, :position
	acts_as_list :scope => :portal

	delegate :name, :to => :solution_category

  after_update :clear_cache, :if => :position_changed?

  CACHEABLE_ATTRS = ["portal_id","position"]
  
  def position_changed?
    self.changes.key?("position")
  end


  def as_cache
    (CACHEABLE_ATTRS.inject({}) do |res, attribute|
      res.merge({ attribute => self.send(attribute) })
    end).with_indifferent_access
  end

  def clear_cache
    account.clear_solution_categories_from_cache
  end

end