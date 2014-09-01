class CreateSubscriptionPlanAddons < ActiveRecord::Migration
  shard :shard_1
  
  def self.up
    create_table :subscription_plan_addons do |t|
      t.column :subscription_addon_id, "bigint unsigned"
      t.column :subscription_plan_id, "bigint unsigned"
    end
  end

  def self.down
    drop_table :plan_addons
  end
end