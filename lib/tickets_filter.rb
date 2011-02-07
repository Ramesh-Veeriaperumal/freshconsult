module TicketsFilter
  DEFAULT_FILTER = [:new_and_my_open]

  SELECTORS = [
    [[:new_and_my_open],  "New & My Open Tickets"  ],
    [[:my_open],          "My Open Tickets"  ],
    [[:my_resolved],      "My Resolved Tickets" ],
    [[:my_closed],        "My Closed Tickets"  ],
    [[:my_due_today],     "My Tickets Due Today"  ],
    [[:my_overdue],       "My Overdue Tickets"  ],
    [[:my_on_hold],       "My Tickets On Hold"  ],
    [[:monitored_by],     "Tickets I'm Monitoring"  ],
    [[:my_all],           "All My Tickets"  ],
    
    [[:new],              "New Tickets"  ],
    [[:open],             "Open Tickets"  ],
    [[:new_and_open],     "New & Open Tickets"  ],
    [[:resolved],         "Resolved Tickets"  ],
    [[:closed],           "Closed Tickets"  ],
    [[:due_today],        "Tickets Due Today"  ],
    [[:overdue],          "Overdue Tickets"  ],
    [[:on_hold],          "Tickets On Hold"  ],
    [[:all],              "All Tickets "  ],
    
    [[:spam],             "Spam"  ],
    [[:deleted],          "Trash"  ]
  ]
  
  SELECTOR_NAMES = Hash[*SELECTORS.inject([]){ |a, v| a += [v[0], v[1]] }]

end
