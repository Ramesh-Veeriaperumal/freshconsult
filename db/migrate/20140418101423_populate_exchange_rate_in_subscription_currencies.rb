class PopulateExchangeRateInSubscriptionCurrencies < ActiveRecord::Migration
	shard :shard_1

	EXCHANGE_RATES = {
    "BRL" => 0.45,
    "EUR" => 1.38,
    "INR" => 0.016,
		"USD" => 1.0,
    "ZAR" => 0.095
	}
  
  def self.up
  	Subscription::Currency.all.each do |currency|
  		currency.update_attributes(:exchange_rate => EXCHANGE_RATES[currency.name])
  	end
  end

  def self.down
  	Subscription::Currency.all.each do |currency|
  		currency.update_attributes(:exchange_rate => 0.0)
  	end
  end
end
