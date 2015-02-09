class PortalForumCategory < ActiveRecord::Base

  belongs_to_account
  belongs_to :portal
  belongs_to :forum_category, :class_name => 'ForumCategory'

  acts_as_list :scope => :portal

  named_scope :main_portal_category,
        :conditions => 'portals.main_portal = 1',
        :joins => :portal

  after_create :clear_cache
  after_destroy :clear_cache
  after_update :clear_cache, :if => :position_changed?

  def position_changed?
    self.changes.key?("position")
  end

  def clear_cache
    account.clear_forum_categories_from_cache if portal.main_portal?
  end
end