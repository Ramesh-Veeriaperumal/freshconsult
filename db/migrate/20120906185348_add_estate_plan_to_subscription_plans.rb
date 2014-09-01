class AddEstatePlanToSubscriptionPlans < ActiveRecord::Migration
  def self.up
  	SubscriptionPlan.create(:name => 'Estate', :amount => 49, :free_agents => 1, :day_pass_amount => 4.00 )
  	
    execute("insert into features(type,account_id,created_at,updated_at) select 'GamificationFeature', account_id, now(), now() from subscriptions where (subscription_plan_id in (3,7))")
  end

  def self.down
  	SubscriptionPlan.find_by_name('Estate').destroy
  end
end
