class AddAgentLimitToSubscriptions < ActiveRecord::Migration
  def self.up
    add_column :subscriptions, :agent_limit, :integer
    remove_column :subscriptions, :user_limit
    remove_column :subscription_plans, :user_limit
  end

  def self.down
    add_column :subscription_plans, :user_limit, :integer
    add_column :subscriptions, :user_limit, :integer
    remove_column :subscriptions, :agent_limit
  end
end
