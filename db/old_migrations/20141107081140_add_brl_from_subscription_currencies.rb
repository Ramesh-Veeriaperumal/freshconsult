class AddBrlFromSubscriptionCurrencies < ActiveRecord::Migration
  shard :shard_1

  BRL_DATA = {
    :name => "BRL", 
    :billing_site => "freshpo-brl-test", 
    :billing_api_key => "test_usPCevjp1KFcrWcdHE3fw4pe8MHKzEdFu", 
    :exchange_rate => 0.45
  }

  PLAN_PRICE =  {
    "Basic" => {
      "USD" => 9.0
    },
    "Pro" => {
      "USD" => 19.0
    },
    "Premium" => {
      "USD" => 29.0
    },

    "Sprout Classic" => {
      "USD" => 9.0
    },
    "Blossom Classic" => {
      "USD" => 19.0
    },
    "Garden Classic" => {
      "USD" => 29.0
    },
    "Estate Classic" => {
      "USD" => 49.0
    },

    "Sprout" => {
      "EUR" => 12.0,
      "INR" => 899.0,
      "USD" => 15.0,
      "ZAR" => 169.0,
      "BRL" => 36.0
    },
    "Blossom" => {
      "EUR" => 16.0,
      "INR" => 1199.0,
      "USD" => 19.0,
      "ZAR" => 229.0,
      "BRL" => 49.0
    },
    "Garden" => {
      "EUR" => 25.0,
      "INR" => 1799.0,
      "USD" => 29.0,
      "ZAR" => 349.0,
      "BRL" => 69.0
    },
    "Estate" => {
      "EUR" => 40.0,
      "INR" => 2999.0,
      "USD" => 49.0,
      "ZAR" => 549.0,
      "BRL" => 119.0
    },
    "Forest" => {
      "EUR" => 62.0,
      "INR" => 4999.0,
      "USD" => 79.0,
      "ZAR" => 889.0,
      "BRL" => 189.0
    }
  }

  def self.up
    Subscription::Currency.create(BRL_DATA)
    SubscriptionPlan.all.each do |plan|
      plan.price = PLAN_PRICE[plan.name]
      plan.save!
    end
  end

  def self.down
    SubscriptionPlan.all.each do |plan|
      plan.price = PLAN_PRICE[plan.name].except(BRL_DATA[:name])
      plan.save!
    end
    Subscription::Currency.find_by_name(BRL_DATA[:name]).destroy
  end
end
