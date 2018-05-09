class AddBrlCurrency < ActiveRecord::Migration
  shard :none
  
  BRL_DATA = {
    :name => "BRL", 
    :billing_site => "freshpo-brl-test", 
    :billing_api_key => "test_usPCevjp1KFcrWcdHE3fw4pe8MHKzEdFu", 
    :exchange_rate => 0.3
  }

  PLAN_PRICE =  {
    "Sprout Jan 17" => {
      "BRL" => 0.0
    },
    "Blossom Jan 17" => {
      "BRL" => 55.0
    },
    "Garden Jan 17" => {
      "BRL" => 110.0
    },
    "Estate Jan 17" => {
      "BRL" => 170.0
    },
    "Forest Jan 17" => {
      "BRL" => 270.0
    }
  }

  def self.up
    Subscription::Currency.create(BRL_DATA)
    SubscriptionPlan.current.each do |plan|
      plan.price = (plan.price).merge(PLAN_PRICE[plan.name])
      plan.save!
    end
  end

  def self.down
    SubscriptionPlan.current.each do |plan|
      plan.price = PLAN_PRICE[plan.name].except(BRL_DATA[:name])
      plan.save!
    end
    Subscription::Currency.find_by_name(BRL_DATA[:name]).destroy
  end
end
