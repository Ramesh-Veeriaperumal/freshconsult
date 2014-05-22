class PopulateSubscriptionCurrencies < ActiveRecord::Migration
	shard :shard_1

  def self.up
		currencies = [
			{ :name => "BRL", :billing_site => "freshpo-brl-test", 
				:billing_api_key => "nXCFiuuDju8YnhL7G1BjJrF61cdY3xe2S"},
			{ :name => "EUR", :billing_site => "freshpo-eur-test", 
				:billing_api_key => "nXCFiuuDju8YnhL7G1BjJrF61cdY3xe2S"},
			{ :name => "INR", :billing_site => "freshpo-inr-test", 
				:billing_api_key => "nXCFiuuDju8YnhL7G1BjJrF61cdY3xe2S"},
			{ :name => "USD", :billing_site => "freshpo-test", 
				:billing_api_key => "fmjVVijvPTcP0RxwEwWV3aCkk1kxVg8e"}, 	
			{ :name => "ZAR", :billing_site => "freshpo-zar-test", 
				:billing_api_key => "nXCFiuuDju8YnhL7G1BjJrF61cdY3xe2S"},
		]
  	Subscription::Currency.create(currencies)
  end

  def self.down
  	execute("delete from subscription_currencies")
  end
end
