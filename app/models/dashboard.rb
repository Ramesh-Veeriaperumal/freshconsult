class Dashboard < ActiveRecord::Base
  self.primary_key = :id

  include Cache::Memcache::Dashboard::Custom::CacheData
  include Dashboard::Custom::DashboardDecorationMethods
  include Redis::HashMethods
  include Dashboard::Custom::CacheKeys

  attr_accessible :name, :deleted, :accessible_attributes, :widgets_attributes

  concerned_with :presenter

  belongs_to_account

  has_many :widgets, class_name: 'DashboardWidget', dependent: :destroy

  has_many :announcements, class_name: 'DashboardAnnouncement', dependent: :destroy

  has_one :accessible, class_name: 'Helpdesk::Access', as: 'accessible', dependent: :destroy

  has_many :group_accesses,
           through: :accessible,
           source: :group_accesses

  has_many :users,
           through: :accessible,
           source: :users

  has_many :groups,
           through: :accessible,
           source: :groups

  accepts_nested_attributes_for :accessible, :widgets, allow_destroy: true

  alias_attribute :helpdesk_accessible, :accessible

  delegate :access_type, to: :accessible

  validates_presence_of :name

  after_commit :clear_custom_dashboard_widgets_cache, except: :destroy
  before_destroy :clear_custom_dashboard_widgets_cache

  after_commit :callback_after_successfull_create_or_update, if: :persisted?
  before_destroy :remove_from_redis_index

  def update_dashboard_index_in_redis(dashboard_object)
    set_key_in_redis_hash(dashboard_index_redis_key, dashboard_object[:id], dashboard_object.to_json)
  end

  def callback_after_successfull_create_or_update
    dashboard_decorator = decorate_dashboard(self)
    update_dashboard_index_in_redis(dashboard_decorator.to_list_hash)
  end

  def remove_from_redis_index
    delete_key_in_redis_hash(dashboard_index_redis_key, id)
  end
end
