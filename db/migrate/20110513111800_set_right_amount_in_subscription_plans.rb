class SetRightAmountInSubscriptionPlans < ActiveRecord::Migration
  def self.up
    execute "update subscription_plans set amount=9.00 where name='Basic'"
    execute "update subscription_plans set amount=19.00 where name='Pro'"
    execute "update subscription_plans set amount=29.00 where name='Premium'"
  end

  def self.down
  end
end
