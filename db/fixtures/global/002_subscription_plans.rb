def self.plan_list(all_addons, estate_addons, garden_addons, blossom_addons, estate_17_addons, garden_17_addons, blossom_17_addons, sprout_17_addons)
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

		{ :name => "Sprout Jan 17", :amount => 0, :free_agents => 50000, :day_pass_amount => 0.00,
    	:addons => sprout_17_addons, :price => plan_price[:sprout_jan_17], :classic => false, :display_name => "Sprout"},
		{ :name => "Blossom Jan 17", :amount => 25, :free_agents => 0, :day_pass_amount => 2.00,
	    :addons => blossom_17_addons, :price => plan_price[:blossom_jan_17], :classic => false, :display_name => "Blossom"},
		{ :name => "Garden Jan 17", :amount => 44, :free_agents => 0, :day_pass_amount => 3.00,
	    :addons => garden_17_addons, :price => plan_price[:garden_jan_17], :classic => false, :display_name => "Garden"},
		{ :name => "Estate Jan 17", :amount => 59, :free_agents => 0, :day_pass_amount => 4.00,
	    :addons => estate_17_addons, :price => plan_price[:estate_jan_17], :classic => false, :display_name => "Estate"},
		{ :name => "Forest Jan 17", :amount => 99, :free_agents => 0, :day_pass_amount => 5.00,
	    :price => plan_price[:forest_jan_17], :classic => false, :display_name => "Forest"},
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
			"GBP" => 0.0
		},
		:blossom_jan_17 => {
			"EUR" => 24.0,
			"INR" => 1599.0,
			"USD" => 25.0,
			"ZAR" => 339.0,
			"GBP" => 19.0
		},
		:garden_jan_17 => {
			"EUR" => 42.0,
			"INR" => 2699.0,
			"USD" => 44.0,
			"ZAR" => 599.0,
			"GBP" => 35.0
		},
		:estate_jan_17 => {
			"EUR" => 58.0,
			"INR" => 3699.0,
			"USD" => 59.0,
			"ZAR" => 809.0,
			"GBP" => 46.0
		},
		:forest_jan_17 => {
			"EUR" => 96.0,
			"INR" => 6299.0,
			"USD" => 99.0,
			"ZAR" => 1379.0,
			"GBP" => 79.0
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
		{ :name => "GBP", :billing_site => "freshpo-gbp-test", :exchange_rate => 1.25,
			:billing_api_key => "test_zsyEST93T9PuAcuNZ0Ehcd2cuCUU8FHgIup"}
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

	all_addons = [ agent_collision, custom_ssl, custom_roles, gamification, layout_customization,
									multiple_business_hours, round_robin, chat, enterprise_reporting, custom_domain,
									custom_slas, custom_mailbox, whitelisted_ips, chat_routing, dynamic_sections,
									custom_surveys, call_center_advanced, helpdesk_restriction,
									ticket_templates, round_robin_load_balancing ]

	estate_addons  = [custom_mailbox, whitelisted_ips, call_center_advanced, skill_based_round_robin]
	garden_addons  = all_addons - [ multiple_business_hours, custom_domain, custom_slas, custom_surveys, ticket_templates ]
	blossom_addons = all_addons + [link_tickets_toggle, parent_child_tickets_toggle] - [ custom_domain ]

	estate_17_addons  = estate_addons
	garden_17_addons  = all_addons + [shared_ownership_toggle] - [custom_domain, custom_surveys, ticket_templates]
	blossom_17_addons = all_addons + [link_tickets_toggle, parent_child_tickets_toggle] - [custom_domain]
	sprout_17_addons  = [custom_domain, call_center_advanced]

  SubscriptionPlan.seed_many(:name, plan_list(all_addons, estate_addons, garden_addons, blossom_addons, estate_17_addons, garden_17_addons, blossom_17_addons, sprout_17_addons))

  Subscription::Currency.seed_many(:name, currencies)
end
