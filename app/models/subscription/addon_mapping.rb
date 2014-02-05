class Subscription::AddonMapping < ActiveRecord::Base	

	belongs_to :subscription
	belongs_to :subscription_addon

	before_create :set_account_id

	def set_account_id
		self.account_id = subscription.account_id
	end
end