class Add2019SubscriptionPlans < ActiveRecord::Migration
  shard :none

  def up
    SubscriptionPlan.create(name: "Sprout Jan 19", amount: 0.0, renewal_period: 1,
      trial_period: 1, free_agents: 50000, day_pass_amount: 0, price: { "EUR" => 0.0,
        "INR" => 0.0, "USD" => 0.0, "ZAR" => 0.0, "GBP" => 0.0, "AUD" => 0.0, "BRL" => 0.0}, classic: true, display_name: "Sprout")
    SubscriptionPlan.create(name: "Blossom Jan 19", amount: 19.0, renewal_period: 1,
      trial_period: 1, free_agents: 0, day_pass_amount: 1, price: { "EUR" => 19.0,
        "INR" => 1399.0, "USD" => 19.0, "ZAR" => 269.0, "GBP" => 15.0, "AUD" => 25.0, "BRL" => 49.0}, classic: true, display_name: "Blossom")
    SubscriptionPlan.create(name: "Garden Jan 19", amount: 35.0, renewal_period: 1,
      trial_period: 1, free_agents: 0, day_pass_amount: 2, price: { "EUR" => 35.0,
        "INR" => 2599.0, "USD" => 35.0, "ZAR" => 499.0, "GBP" => 29.0, "AUD" => 49.0, "BRL" => 129.0}, classic: true, display_name: "Garden")
    SubscriptionPlan.create(name: "Estate Jan 19", amount: 65.0, renewal_period: 1,
      trial_period: 1, free_agents: 0, day_pass_amount: 4, price: { "EUR" => 65.0,
        "INR" => 4699.0, "USD" => 65.0, "ZAR" => 899.0, "GBP" => 49.0, "AUD" => 89.0, "BRL" => 249.0}, classic: true, display_name: "Estate")
    SubscriptionPlan.create(name: "Forest Jan 19", amount: 125.0, renewal_period: 1,
      trial_period: 1, free_agents: 0, day_pass_amount: 6, price: { "EUR" => 125.0,
        "INR" => 8999.0, "USD" => 125.0, "ZAR" => 1799.0, "GBP" => 99.0, "AUD" => 169.0, "BRL" => 469.0}, classic: true, display_name: "Forest")
    SubscriptionPlan.first.clear_cache
  end

  def down
    new_plans = ["Sprout Jan 19", "Blossom Jan 19", "Garden Jan 19", "Estate Jan 19", "Forest Jan 19"]
    plans = SubscriptionPlan.where(name: new_plans)
    plans.destroy_all
    SubscriptionPlan.first.clear_cache
  end
end
