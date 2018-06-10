class Dashboard < ActiveRecord::Base
  self.primary_key = :id
  attr_accessible :name, :deleted, :accessible_attributes, :widgets_attributes

  belongs_to_account

  has_many :widgets, class_name: 'DashboardWidget', dependent: :destroy

  has_one :accessible, class_name: 'Helpdesk::Access', as: 'accessible', dependent: :destroy

  accepts_nested_attributes_for :accessible, :widgets, allow_destroy: true

  alias_attribute :helpdesk_accessible, :accessible

  delegate :group_accesses, :users, :access_type, to: :accessible

  validates_presence_of :name
end
