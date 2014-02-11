class Subscription::AddonMapping < ActiveRecord::Base	
	not_sharded

	belongs_to :subscription
	belongs_to :subscription_addon

	validates_uniqueness_of :subscription_addon_id, :scope => :subscription_id
	before_create :set_account_id

	def set_account_id
		self.account_id = subscription.account_id
	end
end