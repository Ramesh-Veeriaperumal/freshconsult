class Subscription::AddonMapping < ActiveRecord::Base	
  self.primary_key = :id
	not_sharded

	belongs_to :subscription, :class_name => "Subscription"
	belongs_to :subscription_addon, :class_name => "Subscription::Addon"

	validates_uniqueness_of :subscription_addon_id, :scope => :subscription_id
	before_create :set_account_id

	def set_account_id
		self.account_id = subscription.account_id
	end
end