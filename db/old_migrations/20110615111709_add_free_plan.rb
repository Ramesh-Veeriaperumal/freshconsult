class AddFreePlan < ActiveRecord::Migration
  def self.up
    SubscriptionPlan.create(:name => 'Free', :amount => 0)
  end

  def self.down
    free_plan = SubscriptionPlan.find_by_name(SubscriptionPlan::SUBSCRIPTION_PLANS[:free])
    free_plan.destroy
  end
end
