class AddForestPlanToSubscriptionPlans < ActiveRecord::Migration
	shard :shard_1
	
	FOREST_PRICE = {
		"BRL" => 189.0,
		"EUR" => 62.0,
		"INR" => 4999.0,
		"USD" => 79.0,
		"ZAR" => 889.0
	}
  
  def self.up
  	SubscriptionPlan.create(:name => 'Forest', :amount => 79, :free_agents => 0, :day_pass_amount => 3.00,
  		:price =>  FOREST_PRICE)
  end

  def self.down
  	SubscriptionPlan.find_by_name('Forest').destroy
  end
end
