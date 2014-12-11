class AddCurrencyPriceToPlans < ActiveRecord::Migration
	shard :shard_1
  
  def self.up
  	add_column :subscription_plans, :price, :text
  end

  def self.down
  	remove_column :subscription_plans, :price, :text
  end
end
