class Subscription::Currency < ActiveRecord::Base
  self.primary_key = :id
  not_sharded

  has_many :subscriptions,
		:class_name => "Subscription",
		:foreign_key => :subscription_currency_id

end