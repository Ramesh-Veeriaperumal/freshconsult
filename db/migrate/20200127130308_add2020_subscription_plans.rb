class Add2020SubscriptionPlans < ActiveRecord::Migration
  shard :none

  def up
    SubscriptionPlan.create(name: 'Sprout Jan 20', amount: 0, renewal_period: 1, trial_period: 1, free_agents: 50_000, day_pass_amount: 0, classic: true, price: { 'EUR' => 0.0, 'INR' => 0.0, 'USD' => 0.0, 'ZAR' => 0.0, 'GBP' => 0.0, 'AUD' => 0.0, 'BRL' => 0.0 }, display_name: 'Sprout')
    SubscriptionPlan.create(name: 'Blossom Jan 20', amount: 29, renewal_period: 1, trial_period: 1, free_agents: 0, day_pass_amount: 1, classic: true, price: { 'EUR' => 15.0, 'INR' => 999.0, 'USD' => 29.0, 'ZAR' => 209.0, 'GBP' => 11.0, 'AUD' => 19.0, 'BRL' => 39.0 }, display_name: 'Blossom')
    SubscriptionPlan.create(name: 'Garden Jan 20', amount: 45, renewal_period: 1, trial_period: 1, free_agents: 0, day_pass_amount: 2, classic: true, price: { 'EUR' => 29.0, 'INR' => 1999.0, 'USD' => 45.0, 'ZAR' => 409.0, 'GBP' => 21.0, 'AUD' => 39.0, 'BRL' => 109.0, FSM: { EUR: 29.0, INR: 1999.0, USD: 29.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 } }, display_name: 'Garden')
    SubscriptionPlan.create(name: 'Estate Jan 20', amount: 75, renewal_period: 1, trial_period: 1, free_agents: 0, day_pass_amount: 4, classic: true, price: { 'EUR' => 49.0, 'INR' => 3099.0, 'USD' => 75.0, 'ZAR' => 669.0, 'GBP' => 35.0, 'AUD' => 69.0, 'BRL' => 139.0, FSM: { EUR: 29.0, INR: 1999.0, USD: 29.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 } }, display_name: 'Estate')
    SubscriptionPlan.create(name: 'Forest Jan 20', amount: 135, renewal_period: 1, trial_period: 1, free_agents: 0, day_pass_amount: 6, classic: true, price: { 'EUR' => 109.0, 'INR' => 7899.0, 'USD' => 135.0, 'ZAR' => 1499.0, 'GBP' => 85.0, 'AUD' => 149.0, 'BRL' => 409.0, FSM: { EUR: 29.0, INR: 1999.0, USD: 29.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 } }, display_name: 'Forest')
    SubscriptionPlan.create(name: 'Garden Omni Jan 20', amount: 49, renewal_period: 1, trial_period: 1, free_agents: 0, day_pass_amount: 2, classic: true, price: { 'EUR' => 29.0, 'INR' => 1999.0, 'USD' => 49.0, 'ZAR' => 409.0, 'GBP' => 21.0, 'AUD' => 39.0, 'BRL' => 109.0, OMNI: { EUR: 30.0, INR: 2100.0, USD: 30.0, ZAR: 425.0, GBP: 25.0, AUD: 40.0, BRL: 115.0 }, FSM: { EUR: 29.0, INR: 1999.0, USD: 29.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 } }, display_name: 'Garden')
    SubscriptionPlan.create(name: 'Estate Omni Jan 20', amount: 79, renewal_period: 1, trial_period: 1, free_agents: 0, day_pass_amount: 4, classic: true, price: { 'EUR' => 49.0, 'INR' => 3099.0, 'USD' => 79.0, 'ZAR' => 669.0, 'GBP' => 35.0, 'AUD' => 69.0, 'BRL' => 139.0, OMNI: { EUR: 30.0, INR: 2100.0, USD: 30.0, ZAR: 425.0, GBP: 25.0, AUD: 40.0, BRL: 115.0 }, FSM: { EUR: 29.0, INR: 1999.0, USD: 29.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 } }, display_name: 'Estate')
    SubscriptionPlan.create(name: 'Forest Omni Jan 20', amount: 139, renewal_period: 1, trial_period: 1, free_agents: 0, day_pass_amount: 6, classic: true, price: { 'EUR' => 109.0, 'INR' => 7899.0, 'USD' => 139.0, 'ZAR' => 1499.0, 'GBP' => 85.0, 'AUD' => 149.0, 'BRL' => 409.0, OMNI: { EUR: 30.0, INR: 2100.0, USD: 30.0, ZAR: 425.0, GBP: 25.0, AUD: 40.0, BRL: 115.0 }, FSM: { EUR: 29.0, INR: 1999.0, USD: 29.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 } }, display_name: 'Forest')
    sub = SubscriptionPlan.find_by_name('Garden Jan 19')
    sub.price[:FSM] = { EUR: 29.0, INR: 1999.0, USD: 29.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 }
    sub.save!
    sub = SubscriptionPlan.find_by_name('Garden Omni Jan 19')
    sub.price[:OMNI] = { EUR: 10.0, INR: 700.0, USD: 10.0, ZAR: 140.0, GBP: 9.0, AUD: 15.0, BRL: 40.0 }
    sub.price[:FSM] = { EUR: 29.0, INR: 1999.0, USD: 29.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 }
    sub.save!
    sub = SubscriptionPlan.find_by_name('Estate Jan 19')
    sub.price[:FSM] = { EUR: 29.0, INR: 1999.0, USD: 29.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 }
    sub.save!
    sub = SubscriptionPlan.find_by_name('Estate Omni Jan 19')
    sub.price[:OMNI] = { EUR: 20.0, INR: 1500.0, USD: 20.0, ZAR: 285.0, GBP: 15.0, AUD: 25.0, BRL: 75.0 }
    sub.price[:FSM] = { EUR: 29.0, INR: 1999.0, USD: 29.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 }
    sub.save!
    sub = SubscriptionPlan.find_by_name('Forest Jan 19')
    sub.price[:OMNI] = { EUR: 30.0, INR: 2100.0, USD: 30.0, ZAR: 425.0, GBP: 25.0, AUD: 40.0, BRL: 115.0 }
    sub.price[:FSM] = { EUR: 29.0, INR: 1999.0, USD: 29.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 }
    sub.save!
    SubscriptionPlan.first.clear_cache
  end

  def down
    new_plans = ['Sprout Jan 20', 'Blossom Jan 20', 'Garden Jan 20', 'Estate Jan 20', 'Forest Jan 20', 'Garden Omni Jan 20', 'Estate Omni Jan 20', 'Forest Omni Jan 20']
    plans = SubscriptionPlan.where(name: new_plans)
    plans.destroy_all
    SubscriptionPlan.first.clear_cache
  end
end
