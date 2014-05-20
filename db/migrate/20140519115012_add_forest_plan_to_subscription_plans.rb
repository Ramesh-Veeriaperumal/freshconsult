class AddForestPlanToSubscriptionPlans < ActiveRecord::Migration
	shard :shard_1
	
	FOREST_PRICE = {
		"BRL" => 119.0,
		"EUR" => 40.0,
		"INR" => 2999.0,
		"USD" => 79.0,
		"ZAR" => 549.0
	}
  
  def self.up
  	SubscriptionPlan.create(:name => 'Forest', :amount => 79, :free_agents => 0, :day_pass_amount => 3.00,
  		:price =>  FOREST_PRICE)
  end

  def self.down
  	SubscriptionPlan.find_by_name('Forest').destroy
  end
end
