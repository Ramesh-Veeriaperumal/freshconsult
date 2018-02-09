class AddAudCurrency < ActiveRecord::Migration
  shard :none
  
  AUD_DATA = {
    :name => "AUD", 
    :billing_site => "freshpo-aud-test", 
    :billing_api_key => "test_7FdVurIC4fmcuyJrxfr93rdaYA2YSJhwu", 
    :exchange_rate => 1.29
  }

  PLAN_PRICE =  {
    "Sprout Jan 17" => {
      "EUR" => 0.0,
      "INR" => 0.0,
      "USD" => 0.0,
      "ZAR" => 0.0,
      "GBP" => 0.0,
      "AUD" => 0.0
    },
    "Blossom Jan 17" => {
      "EUR" => 24.0,
      "INR" => 1599.0,
      "USD" => 25.0,
      "ZAR" => 339.0,
      "GBP" => 19.0,
      "AUD" => 33.0
    },
    "Garden Jan 17" => {
      "EUR" => 42.0,
      "INR" => 2699.0,
      "USD" => 44.0,
      "ZAR" => 599.0,
      "GBP" => 35.0,
      "AUD" => 55.0
    },
    "Estate Jan 17" => {
      "EUR" => 58.0,
      "INR" => 3699.0,
      "USD" => 59.0,
      "ZAR" => 809.0,
      "GBP" => 46.0,
      "AUD" => 75.0
    },
    "Forest Jan 17" => {
      "EUR" => 96.0,
      "INR" => 6299.0,
      "USD" => 99.0,
      "ZAR" => 1379.0,
      "GBP" => 79.0,
      "AUD" => 125.0
    }
  }

  def self.up
    Subscription::Currency.create(AUD_DATA)
    SubscriptionPlan.current.each do |plan|
      plan.price = PLAN_PRICE[plan.name]
      plan.save!
    end
  end

  def self.down
    SubscriptionPlan.current.each do |plan|
      plan.price = PLAN_PRICE[plan.name].except(AUD_DATA[:name])
      plan.save!
    end
    Subscription::Currency.find_by_name(AUD_DATA[:name]).destroy
  end
end