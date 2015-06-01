module Fdadmin::Subscription::EventsConstants

	SUBSCRIPTION_EVENTS     = [ [:free, "Free Customers"], 
                              [:affiliates, "Affiliates"],
                              [:paid, 'New Revenue'], 
                              [:free_to_paid, "Free to Paid"] ] 

  SUBSCRIPTION_DELETED_EVENT = [ [:deleted, "Deleted Customers"] ]

  SUBSCRIPTION_UPGRADES   = [ [:agents, 'Added Agents' ], [:plan, 'Upgraded Plan' ], 
                              [:period, 'Upgraded Period'], [:agents_plan, 'Added agents & Upgraded Plan'], 
                              [:plan_period, 'Upgraded Plan & Period'], 
                              [:agents_period, 'Added agents & Upgraded Period'], 
                              [:all, 'Added agents, Upgraded Plan & Period' ] ]
  
  SUBSCRIPTION_DOWNGRADES = [ [:agents, 'Removed Agents'], [:plan, 'Downgraded Plan' ], 
                              [:period, 'Downgraded Period'],[:agents_plan, 'Removed agents & Downgraded Plan'], 
                              [:plan_period, 'Downgraded Plan & Period'],
                              [:agents_period, 'Removed agents & Downgraded Period'], 
                              [:all, 'Removed agents, Downgraded Plan & Period' ] ]
end