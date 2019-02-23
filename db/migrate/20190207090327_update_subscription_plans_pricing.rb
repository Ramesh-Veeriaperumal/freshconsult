class UpdateSubscriptionPlansPricing < ActiveRecord::Migration
  shard :none

  def up
    plans_to_pricing_map = {
      "Blossom Jan 19" => { "EUR" => 15.0,
        "INR" => 999.0, "USD" => 15.0, "ZAR" => 209.0, "GBP" => 11.0, "AUD" => 19.0, "BRL" => 39.0},
      "Garden Jan 19" => { "EUR" => 29.0,
        "INR" => 1999.0, "USD" => 29.0, "ZAR" => 409.0, "GBP" => 21.0, "AUD" => 39.0, "BRL" => 109.0},
      "Estate Jan 19" => { "EUR" => 49.0,
        "INR" => 3099.0, "USD" => 49.0, "ZAR" => 669.0, "GBP" => 35.0, "AUD" => 69.0, "BRL" => 139.0},
      "Forest Jan 19" => { "EUR" => 109.0,
        "INR" => 7899.0, "USD" => 109.0, "ZAR" => 1499.0, "GBP" => 85.0, "AUD" => 149.0, "BRL" => 409.0}
    }
    plans_to_pricing_map.each do |plan, pricing|
      subscription_plan = SubscriptionPlan.find_by_name(plan)
      subscription_plan.price = pricing
      subscription_plan.save!
    end
    SubscriptionPlan.first.clear_cache
  end

  def down
    plans_to_pricing_map = {
      "Blossom Jan 19" => { "EUR" => 19.0,
        "INR" => 1399.0, "USD" => 19.0, "ZAR" => 269.0, "GBP" => 15.0, "AUD" => 25.0, "BRL" => 49.0},
      "Garden Jan 19" => { "EUR" => 35.0,
        "INR" => 2599.0, "USD" => 35.0, "ZAR" => 499.0, "GBP" => 29.0, "AUD" => 49.0, "BRL" => 129.0},
      "Estate Jan 19" => { "EUR" => 65.0,
        "INR" => 4699.0, "USD" => 65.0, "ZAR" => 899.0, "GBP" => 49.0, "AUD" => 89.0, "BRL" => 249.0},
      "Forest Jan 19" => { "EUR" => 125.0,
        "INR" => 8999.0, "USD" => 125.0, "ZAR" => 1799.0, "GBP" => 99.0, "AUD" => 169.0, "BRL" => 469.0}
    }
    plans_to_pricing_map.each do |plan, pricing|
      subscription_plan = SubscriptionPlan.find_by_name(plan)
      subscription_plan.price = pricing
      subscription_plan.save!
    end
    SubscriptionPlan.first.clear_cache
  end
end
