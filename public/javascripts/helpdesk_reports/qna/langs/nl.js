var QLANG = QLANG || {};

QLANG['nl'] = {
    "0" : [
            { "label" : "What is"  , "value" : "" , "breadcrumb" : "what_i" , "search_breadcrumb_in" : "3" , "req_key" : "prefix" },
            { "label" : "How many" , "value" : "1", "breadcrumb" : "how_many" , "search_breadcrumb_in" : "1" , "req_key" : "prefix" },
            { "label" : "Which customer" , "value" : "1" , "breadcrumb" : "which_customer" ,"search_breadcrumb_in" : "1" ,"req_key" : "prefix" }
        ],
    "1" : {
        "what_is"     : [
                            { "label" : "Avg resolution time" , "value" :"avg_resolution_time", "breadcrumb" : "group_by" ,"search_breadcrumb_in" : "2" ,"req_key" : "metric"},
                            { "label" : "Avg response time", "value" : "avg_response_time" , "breadcrumb" : "group_by" ,"search_breadcrumb_in" : "2" ,"req_key" : "metric"},
                            { "label" : "Resolution SLA", "value" : "resolution_sla" ,"breadcrumb" : "group_by" ,"search_breadcrumb_in" : "2" ,"req_key" : "metric"},
                            { "label" : "Avg Handle time" , "value" : "avg_handle_time" ,"breadcrumb" : "avg_handle_time", "search_breadcrumb_in" : "2" ,"req_key" : "metric" },
                            { "label" : "Avg Time" , "value" : "avg_time" , "breadcrumb" : "avg_time" ,"search_breadcrumb_in" : "2" ,"req_key" : "metric"},
                            { "label" : "Avg number of " , "value" : "avg_number" , "breadcrumb" : "avg_number" ,"req_key" : "metric"}
                        ],
        "how_many"    : [
                            { "label" : "tickets were received" , "value":"received_tickets", "breadcrumb" : "time", "search_breadcrumb_in" : "3" ,"req_key" : "metric"},
                            { "label" : "tickets were resolved" , "value":"resolved_tickets", "breadcrumb" : "time", "search_breadcrumb_in" : "3" ,"req_key" : "metric"},
                            { "label" : "tickets were reopened" , "value":"reopened_tickets", "breadcrumb" : "time", "search_breadcrumb_in" : "3" ,"req_key" : "metric" },
                            { "label" : "hours were tracked" , "value" : "hours_trakced" ,"search_breadcrumb_in" : "2" , "feature_check" : "timesheet" }
                        ],
        "which_customer" : [
                            { "label" : "has the best"  , "value" : "best"  },
                            { "label" : "has the worst" , "value" : "worst" }
                         ]
    },
    "2" : {	
        "group_by" : [
                            { "label" : "for Agents"    , "value" : "agent" ,  "filter" : "true" , "widget" : "1" , "url": "agents" },
                            { "label" : "for Groups"    , "value" : "group" ,  "filter" : "true" , "widget" : "0" },
                            { "label" : "for Customers" , "value" : "customer" , "filter" : "true" ,"widget" : "1" ,"url": "customers" }
                        ],

        "avg_handle_time" : [
                                { "label" : "for phone calls" , "value" : "phone" },
                                { "label" : "for chats" , "value" : "chat" }
                            ],
        "avg_time" 		  : [
                                { "label" : "in queue for chats" , "value" : "queue_chats"   },
                                { "label" : "a ticket spends in" , "value" : "timespent_in"  }
                                ],
        "avg_number" : 		[
                                { "label" : "agent responses in Resolved or Reopened tickets" , "value" : "agent_responses" },
                                { "label" : "customer responses in Resolved or Reopened tickets", "value" : "customer_reponses" }
                             ]
    },
    "3" : {
        "time" : [
                { "label" : "Today" , "value" : "today" },
                { "label" : "Yesterday" , "value" : "yesterday" }
        ]
    }
}