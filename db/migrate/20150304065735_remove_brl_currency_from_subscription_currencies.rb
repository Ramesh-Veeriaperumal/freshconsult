class RemoveBrlCurrencyFromSubscriptionCurrencies < ActiveRecord::Migration
  shard :shard_1
  
  BRL_DATA = {
    :name => "BRL", 
    :billing_site => "freshpo-brl-test", 
    :billing_api_key => "test_usPCevjp1KFcrWcdHE3fw4pe8MHKzEdFu", 
    :exchange_rate => 0.45
  }

  def self.up
    Subscription::Currency.find_by_name(BRL_DATA[:name]).destroy
  end

  def self.down
    Subscription::Currency.create(BRL_DATA)
  end
end
