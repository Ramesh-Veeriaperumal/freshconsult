class AddingNewSubscriptionPlans < ActiveRecord::Migration
  def self.up
    SubscriptionPlan.create(:name => "Sprout Jan 17", :amount => 0.0, :renewal_period => 1,
      :trial_period => 1, :free_agents => 0, :day_pass_amount => 0, :classic => false, :price => {"EUR" => 0,
        "INR" => 0, "USD" => 0, "ZAR" => 0}, :classic => true, :display_name => "Sprout")
      
    SubscriptionPlan.create(:name => "Blossom Jan 17", :amount => 25.0, :renewal_period => 1,
        :trial_period => 1, :free_agents => 0, :day_pass_amount => 2, :classic => false, :price => {"EUR" => 22,
          "INR" => 1599, "USD" => 25, "ZAR" => 339}, :classic => true, :display_name => "Blossom")
        
    SubscriptionPlan.create(:name => "Garden Jan 17", :amount => 44.0, :renewal_period => 1,
      :trial_period => 1, :free_agents => 0, :day_pass_amount => 3, :classic => false, :price => {"EUR" => 42,
        "INR" => 2699, "USD" => 44, "ZAR" => 599}, :classic => true, :display_name => "Garden")
      
    SubscriptionPlan.create(:name => "Estate Jan 17", :amount => 59.0, :renewal_period => 1,
        :trial_period => 1, :free_agents => 0, :day_pass_amount => 4, :classic => false, :price => {"EUR" => 56,
          "INR" => 3699, "USD" => 59, "ZAR" => 809}, :classic => true, :display_name => "Estate")    
        
    SubscriptionPlan.create(:name => "Forest Jan 17", :amount => 99.0, :renewal_period => 1,
        :trial_period => 1, :free_agents => 0, :day_pass_amount => 5, :classic => false, :price => {"EUR" => 94,
          "INR" => 6299, "USD" => 99, "ZAR" => 1379}, :classic => true, :display_name => "Forest")
  end

  def self.down
    new_plans = ["Sprout Jan 17", "Blossom Jan 17", "Garden Jan 17", "Estate Jan 17", "Forest Jan 17"]
    plans = SubscriptionPlan.where(name: new_plans)
    plans.destroy_all
  end
end
  