class ChangeSubscriptionPlans < ActiveRecord::Migration
  def self.up
    execute "update subscription_plans set name='Pro' where name='Basic'"
    execute "update subscription_plans set name='Basic' where name='Free'"
  end

  def self.down
  end
end
