def self.plan_list(all_addons, garden_addons, blossom_addons)
	[
    { :name => 'Sprout', :amount => 15, :free_agents => 3, :day_pass_amount => 1.00, 
    	:addons => all_addons, :price => plan_price[:sprout] },
    { :name => 'Blossom', :amount => 19, :free_agents => 0, :day_pass_amount => 2.00,
    	:addons => blossom_addons, :price => plan_price[:blossom] },
    { :name => 'Garden', :amount => 29, :free_agents => 0, :day_pass_amount => 2.00,
    	:addons => garden_addons, :price => plan_price[:garden] },
    { :name => 'Estate', :amount => 49, :free_agents => 0, :day_pass_amount => 3.00, 
    	:price => plan_price[:estate] }  
	]
end

def self.plan_price
	{
		:sprout => {
			"BRL" => 36.0,
			"EUR" => 12.0,
			"INR" => 899.0,
			"USD" => 15.0,
			"ZAR" => 169.0
		},
		:blossom => {
			"BRL" => 49.0,
			"EUR" => 16.0,
			"INR" => 1199.0,
			"USD" => 19.0,
			"ZAR" => 229.0
		},
		:garden => {
			"BRL" => 69.0,
			"EUR" => 25.0,
			"INR" => 1799.0,
			"USD" => 29.0,
			"ZAR" => 349.0
		},
		:estate => {
			"BRL" => 119.0,
			"EUR" => 40.0,
			"INR" => 2999.0,
			"USD" => 49.0,
			"ZAR" => 549.0
		}
	}
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
	  a.amount = 19.0
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

	all_addons = [ agent_collision, custom_ssl, custom_roles, gamification, layout_customization, 
									multiple_business_hours, round_robin, chat, enterprise_reporting, custom_domain ]

	garden_addons = all_addons - [ multiple_business_hours, custom_domain ]
	blossom_addons = all_addons - [ custom_domain ]
  SubscriptionPlan.seed_many(:name, plan_list(all_addons, garden_addons, blossom_addons))
end
