class PopulateSubscriptionCurrencyIdInSubscriptions < ActiveRecord::Migration
	shard :all
  
  def self.up
  	execute("UPDATE subscriptions SET subscription_currency_id = 
  		(select id from subscription_currencies WHERE name = 'USD')")
  end

  def self.down
  	execute("UPDATE subscriptions SET subscription_currency_id = NULL")
  end
end
