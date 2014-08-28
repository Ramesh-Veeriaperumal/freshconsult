class Subscription::Currency < ActiveRecord::Base
  not_sharded

  has_many :subscriptions,
		:class_name => "Subscription",
		:foreign_key => :subscription_currency_id

end