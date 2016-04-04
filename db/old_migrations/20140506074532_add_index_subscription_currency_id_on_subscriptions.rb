class AddIndexSubscriptionCurrencyIdOnSubscriptions < ActiveRecord::Migration
	shard :all
  
  def self.up
  	execute <<-SQL
			CREATE INDEX index_subscriptions_on_subscription_currency_id ON subscriptions (subscription_currency_id)
  	SQL
  end

  def self.down
  	execute <<-SQL
			DROP INDEX index_subscriptions_on_subscription_currency_id ON subscriptions
  	SQL
  end
end
