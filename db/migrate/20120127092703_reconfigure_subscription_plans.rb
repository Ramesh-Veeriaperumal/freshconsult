class ReconfigureSubscriptionPlans < ActiveRecord::Migration
  def self.up
    add_column :subscription_plans, :classic, :boolean, :default => false
    
    execute("update subscription_plans set classic=1 where name in ('Basic', 'Pro', 'Premium', 'Free')")
    
    SubscriptionPlan.create([ 
        { :name => 'Sprout', :amount => 9, :free_agents => 1, :day_pass_amount => 1.00 },
        { :name => 'Blossom', :amount => 19, :free_agents => 1, :day_pass_amount => 2.00 },
        { :name => 'Garden', :amount => 29, :free_agents => 1, :day_pass_amount => 2.00 }
      ])
  end

  def self.down
    remove_column :subscription_plans, :classic
  end
end
