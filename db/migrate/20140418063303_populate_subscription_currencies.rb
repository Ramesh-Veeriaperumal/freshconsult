class PopulateSubscriptionCurrencies < ActiveRecord::Migration
	shard :shard_1

  def self.up
		currencies = [
			{ :name => "BRL", :billing_site => "freshpo-brl-test", 
				:billing_api_key => "test_usPCevjp1KFcrWcdHE3fw4pe8MHKzEdFu"},
			{ :name => "EUR", :billing_site => "freshpo-eur-test", 
				:billing_api_key => "test_GCXuNzYMPmyZYsAubdiFNG59Ac5uW63s"},
			{ :name => "INR", :billing_site => "freshpo-inr-test", 
				:billing_api_key => "test_ZMFdEgIWilqkxJiCQYLhqQ1HWoNwlsSV"},
			{ :name => "USD", :billing_site => "freshpo-test", 
				:billing_api_key => "fmjVVijvPTcP0RxwEwWV3aCkk1kxVg8e"}, 	
			{ :name => "ZAR", :billing_site => "freshpo-zar-test", 
				:billing_api_key => "test_HXf2ZGhes0Qbv8ckrXpxLVmuhhXSlZ51"}
		]
  	Subscription::Currency.create(currencies)
  end

  def self.down
  	execute("delete from subscription_currencies")
  end
end
