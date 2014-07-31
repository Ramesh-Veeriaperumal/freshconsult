class Subscription::Currency < ActiveRecord::Base
  not_sharded

  has_many :subscriptions,
		:class_name => "Subscription",
		:foreign_key => :subscription_currency_id

  attr_accessible :name, :billing_site, :billing_api_key, :exchange_rate
end