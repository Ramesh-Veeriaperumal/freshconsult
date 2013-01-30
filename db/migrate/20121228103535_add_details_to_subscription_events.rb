class AddDetailsToSubscriptionEvents < ActiveRecord::Migration
  def self.up
    change_column :subscription_events, :account_id, "bigint unsigned"
    change_column :subscription_events, :code, :integer
    add_column :subscription_events, :subscription_plan_id, :integer
    add_column :subscription_events, :renewal_period, :integer
    add_column :subscription_events, :total_agents, :integer
    add_column :subscription_events, :free_agents, :integer
    add_column :subscription_events, :subscription_affiliate_id, :integer
    add_column :subscription_events, :subscription_discount_id, :integer
    add_column :subscription_events, :revenue_type, :boolean
    add_column :subscription_events, :cmrr, :decimal, :precision => 10, :scale => 2
  end

  def self.down
    remove_column :subscription_events, :cmrr
    remove_column :subscription_events, :revenue_type
    remove_column :subscription_events, :subscription_discount_id
    remove_column :subscription_events, :subscription_affiliate_id
    remove_column :subscription_events, :free_agents
    remove_column :subscription_events, :total_agents
    remove_column :subscription_events, :renewal_period
    remove_column :subscription_events, :subscription_plan_id
    change_column :subscription_events, :code, :string
    change_column :subscription_events, :account_id, :integer
  end
end
