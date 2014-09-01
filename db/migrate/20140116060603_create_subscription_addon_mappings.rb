class CreateSubscriptionAddonMappings < ActiveRecord::Migration
  shard :shard_1
  
  def self.up
    create_table :subscription_addon_mappings do |t|
      t.column :subscription_addon_id, "bigint unsigned"
      t.column :account_id, "bigint unsigned"
      t.column :subscription_id, "bigint unsigned"
    end
  end

  def self.down
    drop_table :subscription_addon_mappings
  end
end