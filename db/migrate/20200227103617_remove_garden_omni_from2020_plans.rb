class RemoveGardenOmniFrom2020Plans < ActiveRecord::Migration
  shard :none

  def up
    plan = SubscriptionPlan.find { |p| p.name == 'Garden Omni Jan 20' }
    plan.destroy
    SubscriptionPlan.first.clear_cache
  end

  def down
    plan = SubscriptionPlan.find { |p| p.name == 'Garden Omni Jan 20' }
    SubscriptionPlan.create(name: 'Garden Omni Jan 20', amount: 49, renewal_period: 1, trial_period: 1, free_agents: 0, day_pass_amount: 2, classic: true, price: { 'EUR' => 29.0, 'INR' => 1999.0, 'USD' => 49.0, 'ZAR' => 409.0, 'GBP' => 21.0, 'AUD' => 39.0, 'BRL' => 109.0, OMNI: { EUR: 30.0, INR: 2100.0, USD: 30.0, ZAR: 425.0, GBP: 25.0, AUD: 40.0, BRL: 115.0 }, FSM: { EUR: 29.0, INR: 1999.0, USD: 29.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 } }, display_name: 'Garden') if plan
    SubscriptionPlan.first.clear_cache
  end
end
