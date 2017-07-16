var QLANG = QLANG || {};

QLANG['en'] = {
    "0": {
        "start": {
            "searchable": "false",
            "req_key": "question_type",
            "options": [{
                    "label": "What is the",
                    "value": "1",
                    "breadcrumb": "what_is",
                    "search_breadcrumb_in": "1"
                },
                {
                    "label": "How many",
                    "value": "2",
                    "breadcrumb": "how_many",
                    "search_breadcrumb_in": "1"
                },
                {
                    "label": "Which customer",
                    "value": "3",
                    "breadcrumb": "which_customer",
                    "search_breadcrumb_in": "1"
                },
                {
                    "label": "Which agent",
                    "value": "4",
                    "breadcrumb": "which_agent",
                    "search_breadcrumb_in": "1",
                    "feature_check" : "show_agent_metrics_feature"
                },
                {
                    "label": "Which group",
                    "value": "5",
                    "breadcrumb": "which_group",
                    "search_breadcrumb_in": "1"
                }
            ]
        }
    },
    "1": {
        "what_is": {
            "searchable": "true",
            "placeholder": "search metrics",
            "req_key": "metric",
            "options": [{
                    "label": "avg first response time",
                    "value": "AVG_FIRST_RESPONSE_TIME",
                    "breadcrumb": "group_by",
                    "search_breadcrumb_in": "2"
                },
                {
                    "label": "avg resolution time",
                    "value": "AVG_RESOLUTION_TIME",
                    "breadcrumb": "group_by",
                    "search_breadcrumb_in": "2",
                },
                {
                    "label": "avg response time",
                    "value": "AVG_RESPONSE_TIME",
                    "breadcrumb": "group_by",
                    "search_breadcrumb_in": "2"
                },
                {
                    "label": "resolution SLA",
                    "value": "RESOLUTION_SLA",
                    "breadcrumb": "group_by",
                    "search_breadcrumb_in": "2"
                },
                {
                    "label": "first response SLA",
                    "value": "RESPONSE_SLA",
                    "breadcrumb": "group_by",
                    "search_breadcrumb_in": "2"
                }
                //{ "label" : "Avg Handle time" , "value" : "avg_handle_time" ,"breadcrumb" : "avg_handle_time", "search_breadcrumb_in" : "2" },
                //{ "label" : "Avg Time" , "value" : "avg_time" , "breadcrumb" : "avg_time" ,"search_breadcrumb_in" : "2" },
                //{ "label" : "Avg number of " , "value" : "avg_number" , "breadcrumb" : "avg_number"}
            ]
        },
        "how_many": {
            "searchable": "true",
            "placeholder": "search metrics",
            "req_key": "metric",
            "options": [{
                    "label": "tickets were received",
                    "value": "RECEIVED_TICKETS",
                    "breadcrumb": "time",
                    "search_breadcrumb_in": "3"
                },
                {
                    "label": "tickets were resolved",
                    "value": "RESOLVED_TICKETS",
                    "breadcrumb": "time",
                    "search_breadcrumb_in": "3"
                },
                {
                    "label": "tickets were reopened",
                    "value": "REOPENED_TICKETS",
                    "breadcrumb": "time",
                    "search_breadcrumb_in": "3"
                },
                /*
                //Timesheet
                { "label" : "hours were tracked"    , "value" : "hours_trakced" , "breadcrumb" : "group_by", "search_breadcrumb_in" : "2" , "feature_check" : "timesheet" },
                { "label" : "billable hours were tracked"    , "value" : "billable_hours_trakced" , "breadcrumb" : "group_by", "search_breadcrumb_in" : "2" , "feature_check" : "timesheet" },
                { "label" : "non-billable hours were tracked"    , "value" : "non_billable_hours_trakced" , "breadcrumb" : "group_by", "search_breadcrumb_in" : "2" , "feature_check" : "timesheet" },
                //Phone
                { "label" : "calls were answered"    , "value" : "calls_answered" , "breadcrumb" : "time", "search_breadcrumb_in" : "3" , "feature_check" : "freshfone" },
                { "label" : "calls were unanswered"    , "value" : "calls_unanswered" , "breadcrumb" : "time", "search_breadcrumb_in" : "3" , "feature_check" : "freshfone" },
                { "label" : "calls were received"    , "value" : "calls_received" , "breadcrumb" : "time", "search_breadcrumb_in" : "3" , "feature_check" : "freshfone" },
                { "label" : "voice mails were received"    , "value" : "voice_mails_received" , "breadcrumb" : "time", "search_breadcrumb_in" : "3" , "feature_check" : "freshfone" },
                { "label" : "calls were transferred"    , "value" : "calls+transferred" , "breadcrumb" : "time", "search_breadcrumb_in" : "3" , "feature_check" : "freshfone" },
                //Chat
                { "label" : "chats were received"    , "value" : "chats_received" , "breadcrumb" : "time", "search_breadcrumb_in" : "3" , "feature_check" : "freshchat" },
                { "label" : "calls were answered"    , "value" : "chats_answered" , "breadcrumb" : "time", "search_breadcrumb_in" : "3" , "feature_check" : "freshchat" },
                { "label" : "calls were missed"    , "value" : "chats_missed" , "breadcrumb" : "time", "search_breadcrumb_in" : "3" , "feature_check" : "freshchat" },
                { "label" : "calls were transferred"    , "value" : "chats_transferred" , "breadcrumb" : "time", "search_breadcrumb_in" : "3" , "feature_check" : "freshchat" },
                */
            ]
        },
        "which_customer": {
            "searchable": "false",
            "req_key": "metric",
            "options": [{
                    "label": "has the most tickets",
                    "value": "RECEIVED_TICKETS",
                    "breadcrumb": "time_limited",
                    "search_breadcrumb_in": "3"
                },
                {
                    "label": "has the most response SLA violations",
                    "value": "RESPONSE_VIOLATED",
                    "breadcrumb": "time_limited",
                    "search_breadcrumb_in": "3"
                },
                {
                    "label": "has the most resolution SLA violations",
                    "value": "RESOLUTION_VIOLATED",
                    "breadcrumb": "time_limited",
                    "search_breadcrumb_in": "3"
                },
                {
                    "label": "has the most unresolved tickets",
                    "value": "UNRESOLVED_TICKETS",
                    "breadcrumb": "time_limited",
                    "search_breadcrumb_in": "3"
                },
                {
                    "label": "has the most reopened tickets",
                    "value": "REOPENED_TICKETS",
                    "breadcrumb": "time_limited",
                    "search_breadcrumb_in": "3"
                }
            ]
        },
        "which_agent": {
            "searchable": "false",
            "req_key": "metric",
            "options": [{
                    "label": "has the most resolved tickets",
                    "value": "RESOLVED_TICKETS",
                    "breadcrumb": "agent_group_by",
                    "search_breadcrumb_in": "2"
                },
                {
                    "label": "has the best average first response time",
                    "value": "AVG_FIRST_RESPONSE_TIME",
                    "breadcrumb": "agent_group_by",
                    "search_breadcrumb_in": "2"
                },
                {
                    "label": "has the best average resolution time",
                    "value": "AVG_RESOLUTION_TIME",
                    "breadcrumb": "agent_group_by",
                    "search_breadcrumb_in": "2"
                },
                {
                    "label": "has the best resolution SLA",
                    "value": "RESOLUTION_SLA",
                    "breadcrumb": "agent_group_by",
                    "search_breadcrumb_in": "2"
                },
            ]
        },
        "which_group": {
            "searchable": "false",
            "req_key": "metric",
            "options": [{
                    "label": "has the most resolved tickets",
                    "value": "RESOLVED_TICKETS",
                    "breadcrumb": "time_limited",
                    "search_breadcrumb_in": "3"
                },
                {
                    "label": "has the best average first response time",
                    "value": "AVG_FIRST_RESPONSE_TIME",
                    "breadcrumb": "time_limited",
                    "search_breadcrumb_in": "3"
                },
                {
                    "label": "has the best average resolution time",
                    "value": "AVG_RESOLUTION_TIME",
                    "breadcrumb": "time_limited",
                    "search_breadcrumb_in": "3"
                },
                {
                    "label": "has the best resolution SLA",
                    "value": "RESOLUTION_SLA",
                    "breadcrumb": "time_limited",
                    "search_breadcrumb_in": "3"
                },
            ]
        }
    },
    "2": {
        "group_by": {
            "searchable": "false",
            "filter": "true",
            "req_key": "filter_value",
            "back_breadcrumb": "group_by",
            "back_breadcrumb_in": "2",
            "options": [{
                    "label": "for agent",
                    "value": "agent_id",
                    "widget_type": "1",
                    "url": "agents",
                    "breadcrumb": "time",
                    "search_breadcrumb_in": "3",
                    "prefix": " for ",
                    "feature_check" : "show_agent_metrics_feature"
                },
                {
                    "label": "in group",
                    "value": "group_id",
                    "widget_type": "2",
                    "breadcrumb": "time",
                    "search_breadcrumb_in": "3",
                    "src": "groups",
                    "prefix": " in "
                },
                {
                    "label": "for customer",
                    "value": "company_id",
                    "widget_type": "1",
                    "url": "companies",
                    "breadcrumb": "time",
                    "search_breadcrumb_in": "3",
                    "prefix": " for "
                }
            ]
        },
        "agent_group_by": {
            "searchable": "false",
            "filter": "true",
            "req_key": "filter_value",
            "back_breadcrumb": "agent_group_by",
            "back_breadcrumb_in": "2",
            "options": [{
                "label": "in group",
                "value": "group_id",
                "widget_type": "2",
                "breadcrumb": "time_limited",
                "search_breadcrumb_in": "3",
                "src": "groups",
                "prefix": " in ",
            }, ]
        },

        "avg_handle_time": {
            "searchable": "false",
            "req_key": "metric",
            "options": [{
                    "label": "for phone calls",
                    "value": "phone"
                },
                {
                    "label": "for chats",
                    "value": "chat"
                }
            ]
        },
        "avg_time": {
            "searchable": "false",
            "req_key": "metric",
            "options": [{
                    "label": "in queue for chats",
                    "value": "queue_chats"
                },
                {
                    "label": "a ticket spends in",
                    "value": "timespent_in"
                }
            ]
        },
        "avg_number": {
            "searchable": "false",
            "req_key": "metric",
            "options": [{
                    "label": "agent responses in Resolved or Reopened tickets",
                    "value": "agent_responses"
                },
                {
                    "label": "customer responses in Resolved or Reopened tickets",
                    "value": "customer_reponses"
                }
            ]
        }
    },
    "3": {
        "time": {
            "searchable": "false",
            "req_key": "date_range",
            "options": [{
                    "label": "today",
                    "value": "today"
                },
                {
                    "label": "yesterday",
                    "value": "yesterday"
                },
                {
                    "label": "last week",
                    "value": "last_week"
                },
                {
                    "label": "last month",
                    "value": "last_month"
                }
            ]
        },
        "time_limited": {
            "searchable": "false",
            "req_key": "date_range",
            "options": [{
                    "label": "today",
                    "value": "today"
                },
                {
                    "label": "yesterday",
                    "value": "yesterday"
                },
            ]
        }
    }
}