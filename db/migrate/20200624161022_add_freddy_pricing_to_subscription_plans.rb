class AddFreddyPricingToSubscriptionPlans < ActiveRecord::Migration
  shard :all

  def up
    price_hash = { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 }.freeze
    ultimate_session_price_hash = { EUR: 500.0, INR: 36000.0, USD: 500.0, ZAR: 7500.0, GBP: 375.0, AUD: 725.0, BRL: 2600.0 }.freeze
    ultimate_price_hash = { EUR: 75.0, INR: 5400.0, USD: 75.0, ZAR: 1100.0, GBP: 55.0, AUD: 110.0, BRL: 390.0 }.freeze
    sub_plans = ['Blossom Jan 17', 'Garden Jan 17', 'Estate Jan 17', 'Forest Jan 17',
                 'Blossom Jan 19', 'Garden Jan 19', 'Estate Jan 19', 'Garden Omni Jan 19', 'Estate Omni Jan 19', 'Forest Jan 19',
                 'Blossom Jan 20', 'Garden Jan 20', 'Estate Jan 20', 'Forest Jan 20', 'Estate Omni Jan 20', 'Forest Omni Jan 20'].freeze
    sub_plans.each do |sub_plan_name|
      sub_plan = SubscriptionPlan.where(:name => sub_plan_name).first
      sub_plan.price[:FREDDY] = {}
      if sub_plan_name.include? 'Forest'
        sub_plan.price[:FREDDY][:ULTIMATE] = ultimate_price_hash
        sub_plan.price[:FREDDY][:ULTIMATE_SESSION] = ultimate_session_price_hash
      end
      sub_plan.price[:FREDDY][:SELF_SERVICE] = price_hash
      sub_plan.price[:FREDDY][:ADDITIONAL_PACKS] = price_hash
      sub_plan.save!
    end
    SubscriptionPlan.first.clear_cache
  end

  def down
    sub_plans = ['Blossom Jan 17', 'Garden Jan 17', 'Estate Jan 17', 'Forest Jan 17',
                 'Blossom Jan 19', 'Garden Jan 19', 'Estate Jan 19', 'Garden Omni Jan 19', 'Estate Omni Jan 19', 'Forest Jan 19',
                 'Blossom Jan 20', 'Garden Jan 20', 'Estate Jan 20', 'Forest Jan 20', 'Estate Omni Jan 20', 'Forest Omni Jan 20']
    sub_plans.each do |sub_plan_name|
      sub_plan = SubscriptionPlan.where(name: sub_plan_name).first
      sub_plan.price.delete(:FREDDY)
      sub_plan.save!
    end
  end
end
