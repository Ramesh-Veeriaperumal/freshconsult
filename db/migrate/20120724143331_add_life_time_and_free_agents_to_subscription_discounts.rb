class AddLifeTimeAndFreeAgentsToSubscriptionDiscounts < ActiveRecord::Migration
  def self.up
    add_column :subscription_discounts, :life_time, :integer
    add_column :subscription_discounts, :free_agents, :integer
  end

  def self.down
    remove_column :subscription_discounts, :free_agents
    remove_column :subscription_discounts, :life_time
  end
end
