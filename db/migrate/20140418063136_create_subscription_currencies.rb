class CreateSubscriptionCurrencies < ActiveRecord::Migration
  shard :shard_1
  
  def self.up
  	create_table :subscription_currencies do |t|
      t.string :name
      t.string :billing_site
      t.string :billing_api_key

      t.timestamps
    end
  end

  def self.down
  	drop_table :subscription_currencies
  end
end
