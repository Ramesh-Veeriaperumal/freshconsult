class PortalSolutionCategory < ActiveRecord::Base

  include Cache::Memcache::Account

  self.primary_key = :id
	belongs_to_account
  belongs_to :portal, :inverse_of => :portal_solution_categories
	belongs_to :solution_category, :class_name => 'Solution::Category'
	belongs_to :solution_category_meta, :class_name => 'Solution::CategoryMeta'
  attr_accessible :portal_id, :solution_category_id, :solution_category_meta_id, :position
	acts_as_list :scope => :portal

  concerned_with :presenter
  publishable
  before_destroy :save_deleted_post_info

  validates :portal, :presence => true

	delegate :name, :to => :solution_category

  after_commit :clear_unassociated_categories_cache

  after_commit ->(obj) { obj.safe_send(:clear_cache_with_condition) }, on: :update

  CACHEABLE_ATTRS = ["portal_id","position"]
  
  def position_changed?
    self.changes.key?("position")
  end


  def as_cache
    (CACHEABLE_ATTRS.inject({}) do |res, attribute|
      res.merge({ attribute => self.safe_send(attribute) })
    end).with_indifferent_access
  end

  def clear_cache
    Account.current.clear_solution_categories_from_cache
  end

  def clear_cache_with_condition
    clear_cache if previous_changes['position'].present?
  end

  def save_deleted_post_info
    @deleted_model_info = as_api_response(:central_publish_destroy)
  end
end
