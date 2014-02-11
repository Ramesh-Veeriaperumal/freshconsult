def self.plan_list(all_addons, garden_addons)
	[
    { :name => 'Sprout', :amount => 15, :free_agents => 3, :day_pass_amount => 1.00, 
    	:addons => all_addons },
    { :name => 'Blossom', :amount => 19, :free_agents => 0, :day_pass_amount => 2.00,
    	:addons => all_addons },
    { :name => 'Garden', :amount => 29, :free_agents => 0, :day_pass_amount => 2.00,
    	:addons => garden_addons },
    { :name => 'Estate', :amount => 49, :free_agents => 0, :day_pass_amount => 3.00 }  
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

	all_addons = [ agent_collision, custom_ssl, custom_roles, gamification, layout_customization, 
									multiple_business_hours, round_robin ]
	garden_addons = all_addons - [ multiple_business_hours ]
  SubscriptionPlan.seed_many(:name, plan_list(all_addons, garden_addons))
end
