def self.plan_list(all_addons, estate_addons, garden_addons, blossom_addons, estate_17_addons, garden_17_addons, blossom_17_addons, sprout_17_addons, estate_19_addons, forest_19_addons, forest_20_addons)
	[
    { :name => 'Sprout', :amount => 15, :free_agents => 3, :day_pass_amount => 1.00,
    	:addons => all_addons, :price => plan_price[:sprout], :classic => true, :display_name => "Sprout" },
    { :name => 'Blossom', :amount => 19, :free_agents => 0, :day_pass_amount => 2.00,
    	:addons => blossom_addons, :price => plan_price[:blossom], :classic => true, :display_name => "Blossom" },
    { :name => 'Garden', :amount => 29, :free_agents => 0, :day_pass_amount => 2.00,
    	:addons => garden_addons, :price => plan_price[:garden], :classic => true, :display_name => "Garden" },
    { :name => 'Estate', :amount => 49, :free_agents => 0, :day_pass_amount => 3.00,
    	:addons => estate_addons, :price => plan_price[:estate], :classic => true, :display_name => "Estate" },
    { :name => 'Forest', :amount => 79, :free_agents => 0, :day_pass_amount => 3.00,
    	:price => plan_price[:forest], :classic => true, :display_name => "Forest" },

    { :name => 'Sprout Jan 17', :amount => 0, :free_agents => 50000, :day_pass_amount => 0.00,
        :addons => sprout_17_addons, :price => plan_price[:sprout_jan_17], :classic => true, :display_name => 'Sprout' },
    { :name => 'Blossom Jan 17', :amount => 25, :free_agents => 0, :day_pass_amount => 2.00,
	    :addons => blossom_17_addons, :price => plan_price[:blossom_jan_17], :classic => true, :display_name => 'Blossom' },
    { :name => 'Garden Jan 17', :amount => 44, :free_agents => 0, :day_pass_amount => 3.00,
	    :addons => garden_17_addons, :price => plan_price[:garden_jan_17], :classic => true, :display_name => 'Garden' },
    { :name => 'Estate Jan 17', :amount => 59, :free_agents => 0, :day_pass_amount => 4.00,
	    :addons => estate_17_addons, :price => plan_price[:estate_jan_17], :classic => true, :display_name => 'Estate' },
    { :name => 'Forest Jan 17', :amount => 99, :free_agents => 0, :day_pass_amount => 5.00,
	    :price => plan_price[:forest_jan_17], :classic => true, :display_name => 'Forest' },

    { name: 'Sprout Jan 19', amount: 0.0, renewal_period: 1, trial_period: 1, free_agents: 50_000,
      day_pass_amount: 0, price: plan_price[:sprout_jan_19], classic: false, display_name: 'Sprout',
      addons: sprout_17_addons },
    { name: 'Blossom Jan 19', amount: 19.0, renewal_period: 1, trial_period: 1, free_agents: 0,
      day_pass_amount: 1, price: plan_price[:blossom_jan_19], classic: false, display_name: 'Blossom',
      addons: blossom_17_addons },
    { name: 'Garden Jan 19', amount: 35.0, renewal_period: 1, trial_period: 1, free_agents: 0,
      day_pass_amount: 2, price: plan_price[:garden_jan_19], classic: false, display_name: 'Garden',
      addons: garden_17_addons },
    { name: 'Estate Jan 19', amount: 65.0, renewal_period: 1, trial_period: 1, free_agents: 0,
      day_pass_amount: 4, price: plan_price[:estate_jan_19], classic: false, display_name: 'Estate',
      addons: estate_19_addons },
    { name: 'Forest Jan 19', amount: 125.0, renewal_period: 1, trial_period: 1, free_agents: 0,
      day_pass_amount: 6, price: plan_price[:forest_jan_19], classic: false, display_name: 'Forest',
      addons: forest_19_addons },
    { name: 'Garden Omni Jan 19', amount: 45.0, renewal_period: 1, trial_period: 1, free_agents: 0,
      day_pass_amount: 2, price: plan_price[:garden_omni_jan_19], classic: false, display_name: 'Garden',
      addons: garden_17_addons },
    { name: 'Estate Omni Jan 19', amount: 85.0, renewal_period: 1, trial_period: 1, free_agents: 0,
      day_pass_amount: 4, price: plan_price[:estate_omni_jan_19], classic: false, display_name: 'Estate',
      addons: estate_19_addons },

    { name: 'Sprout Jan 20', amount: 0.0, renewal_period: 1, trial_period: 1, free_agents: 50_000,
      day_pass_amount: 0, price: plan_price[:sprout_jan_19], classic: true, display_name: 'Sprout',
      addons: sprout_17_addons },
    { name: 'Blossom Jan 20', amount: 19.0, renewal_period: 1, trial_period: 1, free_agents: 0,
      day_pass_amount: 1, price: plan_price[:blossom_jan_19], classic: true, display_name: 'Blossom',
      addons: blossom_17_addons },
    { name: 'Garden Jan 20', amount: 35.0, renewal_period: 1, trial_period: 1, free_agents: 0,
      day_pass_amount: 2, price: plan_price[:garden_jan_19], classic: true, display_name: 'Garden',
      addons: garden_17_addons },
    { name: 'Estate Jan 20', amount: 65.0, renewal_period: 1, trial_period: 1, free_agents: 0,
      day_pass_amount: 4, price: plan_price[:estate_jan_19], classic: true, display_name: 'Estate',
      addons: estate_19_addons },
    { name: 'Forest Jan 20', amount: 125.0, renewal_period: 1, trial_period: 1, free_agents: 0,
      day_pass_amount: 6, price: plan_price[:forest_jan_19], classic: true, display_name: 'Forest',
      addons: forest_20_addons },
    { name: 'Estate Omni Jan 20', amount: 85.0, renewal_period: 1, trial_period: 1, free_agents: 0,
      day_pass_amount: 4, price: plan_price[:estate_omni_jan_19], classic: true, display_name: 'Estate',
      addons: estate_19_addons },
    { name: 'Forest Omni Jan 20', amount: 85.0, renewal_period: 1, trial_period: 1, free_agents: 0,
      day_pass_amount: 4, price: plan_price[:estate_omni_jan_19], classic: true, display_name: 'Forest',
      addons: forest_20_addons }
	]
end

def self.plan_price
	{
		:sprout => {
			"EUR" => 12.0,
			"INR" => 899.0,
			"USD" => 15.0,
			"ZAR" => 169.0
		},
		:blossom => {
			"EUR" => 16.0,
			"INR" => 1199.0,
			"USD" => 19.0,
			"ZAR" => 229.0
		},
		:garden => {
			"EUR" => 25.0,
			"INR" => 1799.0,
			"USD" => 29.0,
			"ZAR" => 349.0
		},
		:estate => {
			"EUR" => 40.0,
			"INR" => 2999.0,
			"USD" => 49.0,
			"ZAR" => 549.0
		},
		:forest => {
			"EUR" => 62.0,
			"INR" => 4999.0,
			"USD" => 79.0,
			"ZAR" => 889.0
		},
		:sprout_jan_17 => {
			"EUR" => 0.0,
			"INR" => 0.0,
			"USD" => 0.0,
			"ZAR" => 0.0,
			"GBP" => 0.0,
			"AUD" => 0.0,
			"BRL" => 0.0
		},
		:blossom_jan_17 => {
			"EUR" => 24.0,
			"INR" => 1599.0,
			"USD" => 25.0,
			"ZAR" => 339.0,
			"GBP" => 19.0,
			"AUD" => 33.0,
			"BRL" => 55.0,
			:FREDDY => {
				:SELF_SERVICE => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
				:ADDITIONAL_PACKS => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
			}
		},
		:garden_jan_17 => {
			"EUR" => 42.0,
			"INR" => 2699.0,
			"USD" => 44.0,
			"ZAR" => 599.0,
			"GBP" => 35.0,
			"AUD" => 55.0,
			"BRL" => 110.0,
			:FREDDY => {
				:SELF_SERVICE => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
				:ADDITIONAL_PACKS => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
			}
		},
		:estate_jan_17 => {
			"EUR" => 58.0,
			"INR" => 3699.0,
			"USD" => 59.0,
			"ZAR" => 809.0,
			"GBP" => 46.0,
			"AUD" => 75.0,
			"BRL" => 170.0,
			:FREDDY => {
				:SELF_SERVICE => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
				:ADDITIONAL_PACKS => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
			}
		},
		:forest_jan_17 => {
			"EUR" => 96.0,
			"INR" => 6299.0,
			"USD" => 99.0,
			"ZAR" => 1379.0,
			"GBP" => 79.0,
			"AUD" => 125.0,
			"BRL" => 270.0,
			:FREDDY => {
				:SELF_SERVICE => { EUR: 500.0, INR: 36000.0, USD: 500.0, ZAR: 7500.0, GBP: 375.0, AUD: 725.0, BRL: 2600.0 },
				:ULTIMATE => { EUR: 75.0, INR: 5400.0, USD: 75.0, ZAR: 1100.0, GBP: 55.0, AUD: 110.0, BRL: 390.0 },
				:ADDITIONAL_PACKS => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
			}
        },
        sprout_jan_19: {
          'EUR' => 0.0,
          'INR' => 0.0,
          'USD' => 0.0,
          'ZAR' => 0.0,
          'GBP' => 0.0,
          'AUD' => 0.0,
          'BRL' => 0.0
        },
        blossom_jan_19: {
          'EUR' => 15.0,
          'INR' => 999.0,
          'USD' => 15.0,
          'ZAR' => 209.0,
          'GBP' => 11.0,
          'AUD' => 19.0,
          'BRL' => 39.0,
          :FSM => { EUR: 29.0, INR: 1999.0, USD: 39.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 },
					:FREDDY => {
						:SELF_SERVICE => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
						:ADDITIONAL_PACKS => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
					}
        },
        garden_jan_19: {
          'EUR' => 29.0,
          'INR' => 1999.0,
          'USD' => 29.0,
          'ZAR' => 409.0,
          'GBP' => 21.0,
          'AUD' => 39.0,
          'BRL' => 109.0,
          :FSM => { EUR: 29.0, INR: 1999.0, USD: 39.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 },
					:FREDDY => {
						:SELF_SERVICE => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
						:ADDITIONAL_PACKS => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
					}
        },
        estate_jan_19: {
          'EUR' => 49.0,
          'INR' => 3099.0,
          'USD' => 49.0,
          'ZAR' => 669.0,
          'GBP' => 35.0,
          'AUD' => 69.0,
          'BRL' => 139.0,
          :FSM => { EUR: 29.0, INR: 1999.0, USD: 39.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 },
					:FREDDY => {
						:SELF_SERVICE => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
						:ADDITIONAL_PACKS => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
					}
        },
        garden_omni_jan_19: {
          'EUR' => 29.0,
          'INR' => 1999.0,
          'USD' => 29.0,
          'ZAR' => 409.0,
          'GBP' => 21.0,
          'AUD' => 39.0,
          'BRL' => 109.0,
          :OMNI => { EUR: 10.0, INR: 700.0, USD: 10.0, ZAR: 140.0, GBP: 9.0, AUD: 15.0, BRL: 40.0 },
          :FSM => { EUR: 29.0, INR: 1999.0, USD: 39.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 },
					:FREDDY => {
						:SELF_SERVICE => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
						:ADDITIONAL_PACKS => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
					}
         },
        estate_omni_jan_19: {
          'EUR' => 49.0,
          'INR' => 3099.0,
          'USD' => 49.0,
          'ZAR' => 669.0,
          'GBP' => 35.0,
          'AUD' => 69.0,
          'BRL' => 139.0,
          :OMNI => { EUR: 20.0, INR: 1500.0, USD: 20.0, ZAR: 285.0, GBP: 15.0, AUD: 25.0, BRL: 75.0 },
          :FSM => { EUR: 29.0, INR: 1999.0, USD: 39.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 },
					:FREDDY => {
						:SELF_SERVICE => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
						:ADDITIONAL_PACKS => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
					}
         },
        forest_jan_19: {
          'EUR' => 109.0,
          'INR' => 7899.0,
          'USD' => 109.0,
          'ZAR' => 1499.0,
          'GBP' => 85.0,
          'AUD' => 149.0,
          'BRL' => 409.0,
          :OMNI => { EUR: 30.0, INR: 2100.0, USD: 30.0, ZAR: 425.0, GBP: 25.0, AUD: 40.0, BRL: 115.0 },
          :FSM => { EUR: 29.0, INR: 1999.0, USD: 39.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 }
        },
        sprout_jan_20: {
          'EUR' => 0.0,
          'INR' => 0.0,
          'USD' => 0.0,
          'ZAR' => 0.0,
          'GBP' => 0.0,
          'AUD' => 0.0,
          'BRL' => 0.0
        },
        blossom_jan_20: {
          'EUR' => 15.0,
          'INR' => 999.0,
          'USD' => 15.0,
          'ZAR' => 209.0,
          'GBP' => 11.0,
          'AUD' => 19.0,
          'BRL' => 39.0,
          :FSM => { EUR: 29.0, INR: 1999.0, USD: 39.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 },
					:FREDDY => {
						:SELF_SERVICE => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
						:ADDITIONAL_PACKS => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
					}
        },
        garden_jan_20: {
          'EUR' => 29.0,
          'INR' => 1999.0,
          'USD' => 29.0,
          'ZAR' => 409.0,
          'GBP' => 21.0,
          'AUD' => 39.0,
          'BRL' => 109.0,
          :FSM => { EUR: 29.0, INR: 1999.0, USD: 39.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 },
					:FREDDY => {
						:SELF_SERVICE => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
						:ADDITIONAL_PACKS => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
					}
        },
        garden_omni_jan_20: {
          'EUR' => 29.0,
          'INR' => 1999.0,
          'USD' => 29.0,
          'ZAR' => 409.0,
          'GBP' => 21.0,
          'AUD' => 39.0,
          'BRL' => 109.0,
          :OMNI => { EUR: 30.0, INR: 2100.0, USD: 30.0, ZAR: 425.0, GBP: 25.0, AUD: 40.0, BRL: 115.0 },
          :FSM => { EUR: 29.0, INR: 1999.0, USD: 39.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 },
					:FREDDY => {
						:SELF_SERVICE => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
						:ADDITIONAL_PACKS => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
					}
        },
        estate_jan_20: {
          'EUR' => 49.0,
          'INR' => 3099.0,
          'USD' => 49.0,
          'ZAR' => 669.0,
          'GBP' => 35.0,
          'AUD' => 69.0,
          'BRL' => 139.0,
          :FSM => { EUR: 29.0, INR: 1999.0, USD: 39.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 },
					:FREDDY => {
						:SELF_SERVICE => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
						:ADDITIONAL_PACKS => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
					}
        },
        estate_omni_jan_20: {
          'EUR' => 49.0,
          'INR' => 3099.0,
          'USD' => 49.0,
          'ZAR' => 669.0,
          'GBP' => 35.0,
          'AUD' => 69.0,
          'BRL' => 139.0,
          :OMNI => { EUR: 30.0, INR: 2100.0, USD: 30.0, ZAR: 425.0, GBP: 25.0, AUD: 40.0, BRL: 115.0 },
          :FSM => { EUR: 29.0, INR: 1999.0, USD: 39.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 },
					:FREDDY => {
						:SELF_SERVICE => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
						:ADDITIONAL_PACKS => { EUR: 100.0, INR: 7200.0, USD: 100.0, ZAR: 1500.0, GBP: 75.0, AUD: 145.0, BRL: 520.0 },
					}
         },
        forest_jan_20: {
          'EUR' => 109.0,
          'INR' => 7899.0,
          'USD' => 109.0,
          'ZAR' => 1499.0,
          'GBP' => 85.0,
          'AUD' => 149.0,
          'BRL' => 409.0,
          :FSM => { EUR: 29.0, INR: 1999.0, USD: 39.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 }
        },
        forest_omni_jan_20: {
          'EUR' => 109.0,
          'INR' => 7899.0,
          'USD' => 109.0,
          'ZAR' => 1499.0,
          'GBP' => 85.0,
          'AUD' => 149.0,
          'BRL' => 409.0,
          :OMNI => { EUR: 30.0, INR: 2100.0, USD: 30.0, ZAR: 425.0, GBP: 25.0, AUD: 40.0, BRL: 115.0 },
          :FSM => { EUR: 29.0, INR: 1999.0, USD: 39.0, ZAR: 399.0, GBP: 25.0, AUD: 39.0, BRL: 99.0 }
        }
	}
end

def self.currencies
	[
		{ :name => "EUR", :billing_site => "freshpo-eur-test", :exchange_rate => 1.38,
			:billing_api_key => "test_GCXuNzYMPmyZYsAubdiFNG59Ac5uW63s"},
		{ :name => "INR", :billing_site => "freshpo-inr-test", :exchange_rate => 0.016,
			:billing_api_key => "test_ZMFdEgIWilqkxJiCQYLhqQ1HWoNwlsSV"},
		{ :name => "USD", :billing_site => "freshpo-test", :exchange_rate => 1,
			:billing_api_key => "fmjVVijvPTcP0RxwEwWV3aCkk1kxVg8e"},
		{ :name => "ZAR", :billing_site => "freshpo-zar-test", :exchange_rate => 0.095,
			:billing_api_key => "test_HXf2ZGhes0Qbv8ckrXpxLVmuhhXSlZ51"},
		{ :name => "GBP", :billing_site => "freshpo-gbp-test", :exchange_rate => 1.42,
			:billing_api_key => "test_zsyEST93T9PuAcuNZ0Ehcd2cuCUU8FHgIup"},
		{ :name => "AUD", :billing_site => "freshpo-aud-test", :exchange_rate => 0.78,
			:billing_api_key => "test_7FdVurIC4fmcuyJrxfr93rdaYA2YSJhwu"},
		{ :name => "BRL", :billing_site => "freshpo-brl-test", :exchange_rate => 0.29,
			:billing_api_key => "test_usPCevjp1KFcrWcdHE3fw4pe8MHKzEdFu"}
	]
end

unless Account.current
	addon_types = Subscription::Addon::ADDON_TYPES
	agent_collision = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Agent Collision'
	  a.amount = 5.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:agent_quantity]
	end

	custom_ssl = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Custom Ssl'
	  a.amount = 15.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:portal_quantity]
	end

	custom_roles = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Custom Roles'
	  a.amount = 5.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:agent_quantity]
	end

	gamification = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Gamification'
	  a.amount = 5.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:agent_quantity]
	end

	layout_customization = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Layout Customization'
	  a.amount = 49.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:portal_quantity]
	end

	multiple_business_hours = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Multiple Business Hours'
	  a.amount = 5.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:agent_quantity]
	end

	round_robin = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Round Robin'
	  a.amount = 3.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:agent_quantity]
	end

	round_robin_load_balancing = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Round Robin Load Balancing'
	  a.amount = 5.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:agent_quantity]
	end

	chat = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Chat'
	  a.amount = 8.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:agent_quantity]
	end

	enterprise_reporting = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Enterprise Reporting'
	  a.amount = 8.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:agent_quantity]
	end

	custom_domain = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Custom Domain'
	  a.amount = 3.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:agent_quantity]
	end

	custom_slas = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Custom Slas'
	  a.amount = 5.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:agent_quantity]
	end

	custom_mailbox = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Custom Mailbox'
	  a.amount = 15.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:agent_quantity]
	end

	whitelisted_ips = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Whitelisted Ips'
	  a.amount = 15.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:agent_quantity]
	end

	chat_routing = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Chat Routing'
	  a.amount = 5.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:agent_quantity]
	end

	call_center_advanced = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Call Center Advanced'
	  a.amount = 24.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:agent_quantity]
	end

	dynamic_sections = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Dynamic Sections'
	  a.amount = 10.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:agent_quantity]
	end

	custom_surveys = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Custom Surveys'
	  a.amount = 5.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:agent_quantity]
	end

	helpdesk_restriction = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Helpdesk Restriction'
	  a.amount = 49.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:for_account]
	end

	ticket_templates = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Ticket Templates'
	  a.amount = 5.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:agent_quantity]
	end

	link_tickets_toggle = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Link Tickets'
	  a.amount = 5.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:agent_quantity]
	end

	parent_child_tickets_toggle = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Parent Child Tickets'
	  a.amount = 6.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:agent_quantity]
	end

	shared_ownership_toggle = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Shared Ownership'
	  a.amount = 6.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:agent_quantity]
	end

	skill_based_round_robin = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Skill Based Round Robin'
	  a.amount = 8.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:agent_quantity]
	end

	one_contact_multiple_companies = Subscription::Addon.seed(:name) do |a|
	  a.name = 'One Contact Multiple Companies'
	  a.amount = 69.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:for_account]
	end

	unique_external_id = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Unique External Id'
	  a.amount = 25.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:for_account]
	end

	sandbox = Subscription::Addon.seed(:name) do |a|
	  a.name = 'Sandbox'
	  a.amount = 69.0
	  a.renewal_period = 1
	  a.addon_type = addon_types[:for_account]
	end

  fluffy_forest = Subscription::Addon.seed(:name) do |a|
    a.name = 'Fluffy Forest'
    a.amount = 2000.0
    a.renewal_period = 1
    a.addon_type = addon_types[:for_account]
  end

  fluffy_higher_plan1 = Subscription::Addon.seed(:name) do |a|
    a.name = 'Fluffy Higher Plan1'
    a.amount = 4000.0
    a.renewal_period = 1
    a.addon_type = addon_types[:for_account]
  end

  fluffy_higher_plan2 = Subscription::Addon.seed(:name) do |a|
    a.name = 'Fluffy Higher Plan2'
    a.amount = 5000.0
    a.renewal_period = 1
    a.addon_type = addon_types[:for_account]
  end

  fluffy_higher_plan3 = Subscription::Addon.seed(:name) do |a|
    a.name = 'Fluffy Higher Plan3'
    a.amount = 7000.0
    a.renewal_period = 1
    a.addon_type = addon_types[:for_account]
  end

  fluffy_higher_plan4 = Subscription::Addon.seed(:name) do |a|
    a.name = 'Fluffy Higher Plan4'
    a.amount = 8000.0
    a.renewal_period = 1
    a.addon_type = addon_types[:for_account]
  end

  field_service_management = Subscription::Addon.seed(:name) do |a|
    a.name = 'Field Service Management'
    a.amount = 29.0
    a.renewal_period = 1
    a.addon_type = addon_types[:field_agent_quantity]
  end

  freddy_ultimate = Subscription::Addon.seed(:name) do |a|
    a.name = 'Freddy Ultimate'
    a.amount = 75.0
    a.renewal_period = 1
    a.addon_type = addon_types[:agent_quantity]
  end

	freddy_self_service = Subscription::Addon.seed(:name) do |a|
		a.name = 'Freddy Self Service'
		a.amount = 100.0
		a.renewal_period = 1
		a.addon_type = addon_types[:on_off]
  end

	freddy_session_packs = Subscription::Addon.seed(:name) do |a|
		a.name = 'Freddy Session Packs Monthly'
		a.amount = 500.0
		a.renewal_period = 1
		a.addon_type = addon_types[:session_packs]
	end

	all_addons = [ agent_collision, custom_ssl, custom_roles, gamification, layout_customization,
	               multiple_business_hours, round_robin, chat, enterprise_reporting, custom_domain,
	               custom_slas, custom_mailbox, whitelisted_ips, chat_routing, dynamic_sections,
	               custom_surveys, call_center_advanced, helpdesk_restriction,
	               ticket_templates, round_robin_load_balancing, one_contact_multiple_companies, unique_external_id, sandbox ]

	estate_addons  = [custom_mailbox, whitelisted_ips, call_center_advanced, skill_based_round_robin, field_service_management, freddy_self_service, freddy_session_packs]
	garden_addons  = all_addons + [shared_ownership_toggle, field_service_management, freddy_self_service, freddy_session_packs] - [multiple_business_hours, custom_domain, custom_slas, custom_surveys, ticket_templates, sandbox]
  blossom_addons = all_addons + [link_tickets_toggle, parent_child_tickets_toggle, field_service_management] - [custom_domain, sandbox]

	estate_17_addons  = estate_addons + [sandbox]
	garden_17_addons  = all_addons + [shared_ownership_toggle, field_service_management, freddy_self_service, freddy_session_packs] - [custom_domain, custom_surveys, ticket_templates, sandbox]
  blossom_17_addons = all_addons + [link_tickets_toggle, parent_child_tickets_toggle, field_service_management, freddy_self_service, freddy_session_packs] - [custom_domain, one_contact_multiple_companies, sandbox]
	sprout_17_addons  = [custom_domain, call_center_advanced]

	estate_jan_19 = estate_17_addons + [fluffy_forest, fluffy_higher_plan1, fluffy_higher_plan2, fluffy_higher_plan3, fluffy_higher_plan4]

	forest_jan_19 = [fluffy_higher_plan1, fluffy_higher_plan2, fluffy_higher_plan3, fluffy_higher_plan4, field_service_management, freddy_ultimate, freddy_self_service, freddy_session_packs]

  forest_jan_20 = forest_jan_19

  SubscriptionPlan.seed_many(:name, plan_list(all_addons, estate_addons, garden_addons, blossom_addons, estate_17_addons, garden_17_addons, blossom_17_addons, sprout_17_addons, estate_jan_19, forest_jan_19, forest_jan_20))

  Subscription::Currency.seed_many(:name, currencies)
end
