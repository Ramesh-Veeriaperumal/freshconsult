class AddDayPassColumnsToSubscriptions < ActiveRecord::Migration
  def self.up
    add_column :subscriptions, :free_agents, :integer
    add_column :subscriptions, :day_pass_amount, :decimal, :precision => 10, :scale => 2
  end

  def self.down
    remove_column :subscriptions, :day_pass_amount
    remove_column :subscriptions, :free_agents
  end
end
