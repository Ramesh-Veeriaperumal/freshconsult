class UpdatePlans < ActiveRecord::Migration
  def self.up
  	SubscriptionPlan.update_all("classic = 1, name = CONCAT(name, ' Classic')", {:name => ['Sprout', 'Blossom', 'Garden', 'Estate']})

  	new_plans = [
  		{:name => 'Sprout', :amount => 15, :free_agents => 3, :day_pass_amount => 1.00 },
  		{:name => 'Blossom', :amount => 19, :free_agents => 0, :day_pass_amount => 2.00 },
  		{:name => 'Garden', :amount => 29, :free_agents => 0, :day_pass_amount => 2.00 },
  		{:name => 'Estate', :amount => 49, :free_agents => 0, :day_pass_amount => 4.00 },
  	]
  	SubscriptionPlan.create(new_plans)
  end

  def self.down
  	SubscriptionPlan.destroy_all({:name => ['Sprout', 'Blossom', 'Garden', 'Estate']})
    SubscriptionPlan.update_all("classic = 0, name = REPLACE(name, ' Classic', '')", {:name => ['Sprout Classic', 'Blossom Classic', 'Garden Classic', 'Estate Classic']})
  end
end
