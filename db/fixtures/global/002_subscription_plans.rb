def self.plan_list(all_addons, estate_addons, garden_addons, blossom_addons)
	[
    { :name => 'Sprout', :amount => 15, :free_agents => 3, :day_pass_amount => 1.00, 
    	:addons => all_addons, :price => plan_price[:sprout] },
    { :name => 'Blossom', :amount => 19, :free_agents => 0, :day_pass_amount => 2.00,
    	:addons => blossom_addons, :price => plan_price[:blossom] },
    { :name => 'Garden', :amount => 29, :free_agents => 0, :day_pass_amount => 2.00,
    	:addons => garden_addons, :price => plan_price[:garden] },
    { :name => 'Estate', :amount => 49, :free_agents => 0, :day_pass_amount => 3.00, 
    	:addons => estate_addons, :price => plan_price[:estate] },
    { :name => 'Forest', :amount => 79, :free_agents => 0, :day_pass_amount => 3.00, 
    	:price => plan_price[:forest] }   
	]
end

def self.plan_price
	{
		:sprout => {			
			"EUR" => 12.0,
			"INR" => 899.0,
			"USD" => 15.0,
			"ZAR" => 169.0,
			"BRL" => 36.0
		},
		:blossom => {		
			"EUR" => 16.0,
			"INR" => 1199.0,
			"USD" => 19.0,
			"ZAR" => 229.0,
			"BRL"	=> 49.0
		},
		:garden => {			
			"EUR" => 25.0,
			"INR" => 1799.0,
			"USD" => 29.0,
			"ZAR" => 349.0,
			"BRL" => 69.0
		},
		:estate => {			
			"EUR" => 40.0,
			"INR" => 2999.0,
			"USD" => 49.0,
			"ZAR" => 549.0,
			"BRL" => 119.0
		},
		:forest => {		
			"EUR" => 62.0,
			"INR" => 4999.0,
			"USD" => 79.0,
			"ZAR" => 889.0,
			"BRL" => 189.0,
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
		{ :name => "BRL", :billing_site => "freshpo-brl-test", :exchange_rate => 0.45,
  		:billing_api_key => "test_usPCevjp1KFcrWcdHE3fw4pe8MHKzEdFu" }
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

	all_addons = [ agent_collision, custom_ssl, custom_roles, gamification, layout_customization, 
									multiple_business_hours, round_robin, chat, enterprise_reporting, custom_domain,
									custom_slas, custom_mailbox, whitelisted_ips ]

	estate_addons = [custom_mailbox, whitelisted_ips]
	garden_addons = all_addons - [ multiple_business_hours, custom_domain, custom_slas ]
	blossom_addons = all_addons - [ custom_domain ]
  SubscriptionPlan.seed_many(:name, plan_list(all_addons, estate_addons, garden_addons, blossom_addons))

  Subscription::Currency.seed_many(:name, currencies)
end
