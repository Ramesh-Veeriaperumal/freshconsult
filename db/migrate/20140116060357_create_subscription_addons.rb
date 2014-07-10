class CreateSubscriptionAddons < ActiveRecord::Migration
  shard :shard_1
  
  def self.up
  	create_table :subscription_addons do |t|
      t.string 	:name
      t.decimal :amount, :precision => 10, :scale => 2, :default => 0.0
      t.integer :renewal_period
      t.integer :addon_type
      
      t.timestamps
    end
  end

  def self.down
  	drop_table :subscription_addons
  end
end