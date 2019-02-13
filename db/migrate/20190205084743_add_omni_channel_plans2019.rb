class AddOmniChannelPlans2019 < ActiveRecord::Migration
  def up
    SubscriptionPlan.create(name: "Garden Omni Jan 19", amount: 39.0, renewal_period: 1,
                            trial_period: 1, free_agents: 0, day_pass_amount: 2, price: { "EUR" => 39.0,
                                                                                          "INR" => 2699.0, "USD" => 39.0, "ZAR" => 549.0, "GBP" => 29.0, "AUD" => 55.0, "BRL" => 149.0}, classic: true, display_name: "Garden")
    SubscriptionPlan.create(name: "Estate Omni Jan 19", amount: 69.0, renewal_period: 1,
                            trial_period: 1, free_agents: 0, day_pass_amount: 4, price: { "EUR" => 69.0,
                                                                                          "INR" => 4599.0, "USD" => 69.0, "ZAR" => 959.0, "GBP" => 49.0, "AUD" => 99.0, "BRL" => 215.0}, classic: true, display_name: "Estate")
    SubscriptionPlan.first.clear_cache
  end

  def down
    new_plans = ["Estate Omni Jan 19", "Forest Omni Jan 19"]
    plans = SubscriptionPlan.where(name: new_plans)
    plans.destroy_all
    SubscriptionPlan.first.clear_cache
  end
end
