class AddFsmPricingForBlossom < ActiveRecord::Migration
  shard :none

  def up
    sub = SubscriptionPlan.find_by_name('Blossom Jan 19')
    sub.price[:FSM] = { EUR: 29.0, INR: 1999.0, USD: 29.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 }
    sub.save!
  end

  def down
    sub = SubscriptionPlan.find_by_name('Blossom Jan 19').price.delete(:FSM)
    sub.save!
  end
end
