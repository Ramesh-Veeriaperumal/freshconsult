class AddExchangeRateToSubscriptionCurrencies < ActiveRecord::Migration
	shard :shard_1
  
  def self.up
  	add_column :subscription_currencies, :exchange_rate, :decimal, 
  	:precision => 10, :scale => 5  							
  end

  def self.down
  	remove_column :subscription_currencies, :exchange_rate
  end
end
