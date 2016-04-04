class AddDayPassColumnsToSubscriptionPlans < ActiveRecord::Migration
  def self.up
    add_column :subscription_plans, :free_agents, :integer
    add_column :subscription_plans, :day_pass_amount, :decimal, :precision => 10, :scale => 2
    
    [ [ 'Basic', 1.00 ], [ 'Pro', 2.00 ], [ 'Premium', 2.00 ] ].each do |s_p|
      execute("update subscription_plans set free_agents=1, day_pass_amount=#{s_p[1]} where name='#{s_p[0]}'")
    end
  end

  def self.down
    remove_column :subscription_plans, :day_pass_amount
    remove_column :subscription_plans, :free_agents
  end
end
