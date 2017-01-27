class AddColumnDisplayNameToSubscriptionPlans < ActiveRecord::Migration
  shard :none
  
  def self.up
    Lhm.change_table :subscription_plans, :atomic_switch => true do |m|
      m.add_column :display_name, "varchar(255) DEFAULT NULL"
    end
  end
  
  def self.down
    Lhm.change_table :subscription_plans, :atomic_switch => true do |m|
      m.remove_column :display_name
    end
  end
end
