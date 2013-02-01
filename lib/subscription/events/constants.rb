module Subscription::Events::Constants

	SUBCRIPTION_INFO  = { :subscription_plan_id => :subscription_plan_id, 
		                    :renewal_period => :renewal_period, 
		                    :total_agents => :agent_limit, :free_agents => :free_agents,
		                    :subscription_affiliate_id => :subscription_affiliate_id,
		                    :subscription_discount_id => :subscription_discount_id }

	CODES             = { :free => 100, :affiliates => 125, :paid => 150, 
												:free_to_paid => 200, :upgrades => 250, :downgrades => 450,
												:recurring => 650, :deleted => 0 }

	ADDITIVE_VALUES   = { :agent_change => 1, :plan_change => 3, :period_change => 5, 
												:no_change => 0 }     

	UPGRADES          = { :agents => 251, :plan => 253, :period => 255, :agents_plan => 254, 
												:agents_period => 256, :plan_period => 258, :all => 259 }

	DOWNGRADES        = { :agents => 451, :plan => 453, :period => 455, :agents_plan => 454, 
												:agents_period => 456, :plan_period => 458, :all => 459 }

	METRICS           = { :cmrr => (100..449).to_a, :upgrades => (250..449).to_a, 
												:downgrades => (450..649).to_a }

	REVENUE_TYPES     = { :new => 0, :existing => 1 }	

	STATES            = { :trial => "trial", :free => "free", :active => "active" }			

end