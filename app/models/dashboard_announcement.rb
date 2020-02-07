class DashboardAnnouncement < ActiveRecord::Base
  include Cache::Memcache::Dashboard::Custom::CacheData

  attr_accessible :dashboard_id, :announcement_text, :active, :user_id

  MAX_TEXT_LIMIT = 150

  belongs_to_account
  belongs_to :dashboard
  belongs_to :user

  concerned_with :presenter

  publishable on: [:create]

  validates :dashboard_id, :user_id, :announcement_text, presence: true
  validates :announcement_text, length: { maximum: MAX_TEXT_LIMIT, allow_nil: false }

  scope :active, -> { where(active: true) }

  after_commit :clear_dashboard_cache, except: :destroy

  def deactivate
    self.active = false
    self.save
  end

  def clear_dashboard_cache
    MemcacheKeys.delete_from_cache(dashboard_cache_key(dashboard_id))
  end
end
