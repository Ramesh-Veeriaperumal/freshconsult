class PopulateCurrencyPriceInPlans < ActiveRecord::Migration
shard :shard_1
	
	PLAN_PRICE =	{
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
			"BRL" => 36.0,
			"EUR" => 12.0,
			"INR" => 899.0,
			"USD" => 15.0,
			"ZAR" => 169.0
		},
		"Blossom" => {
			"BRL" => 49.0,
			"EUR" => 16.0,
			"INR" => 1199.0,
			"USD" => 19.0,
			"ZAR" => 229.0
		},
		"Garden" => {
			"BRL" => 69.0,
			"EUR" => 25.0,
			"INR" => 1799.0,
			"USD" => 29.0,
			"ZAR" => 349.0
		},
		"Estate" => {
			"BRL" => 119.0,
			"EUR" => 40.0,
			"INR" => 2999.0,
			"USD" => 49.0,
			"ZAR" => 549.0
		}
	}
	def self.up
		SubscriptionPlan.all.each do |plan|
			plan.update_attributes(:price => PLAN_PRICE[plan.name])
		end
	end

	def self.down
		SubscriptionPlan.all.each do |plan|
			plan.update_attributes(:price => nil)
		end
	end

end
