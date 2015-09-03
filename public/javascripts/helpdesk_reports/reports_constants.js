window.HelpdeskReports = window.HelpdeskReports || {};

HelpdeskReports.Constants = {
    Glance: {
        metrics: { 
            "RECEIVED_TICKETS" : { 
                name : "CREATED TICKETS",
                title: "Created Tickets",
                description: "The tickets that were created in the helpdesk in the selected time period",
                css  : ["report-arrow up negative", "report-arrow down positive"]
            },
            "RESOLVED_TICKETS" : { 
                name : "RESOLVED TICKETS",
                title: "Resolved Tickets",
                description: "The tickets that were created anytime and resolved in the selected time period",
                css  : ["report-arrow up positive", "report-arrow down negative"]
            },
            "REOPENED_TICKETS" : { 
                name : "REOPENED TICKETS",
                title: "Reopened Tickets",
                description: "The tickets that were created anytime and reopened in the selected time period",
                css  : ["report-arrow up negative", "report-arrow down positive"]
            },
            "AVG_FIRST_RESPONSE_TIME" : { 
                name : "AVERAGE 1ST RESPONSE TIME",
                title: "Avg 1st Response Time",
                description: "Average first response time of all the first responses made in the selected time period",
                css  : ["report-arrow up negative", "report-arrow down positive"]
            },
            "AVG_RESPONSE_TIME" : { 
                name : "AVERAGE RESPONSE TIME",
                title: "Avg Response Time",
                description: "Average response time of all the responses made in the selected time period",
                css  : ["report-arrow up negative", "report-arrow down positive"]
            },
            "AVG_RESOLUTION_TIME" : { 
                name : "AVERAGE RESOLUTION TIME",
                title: "Avg Resolution Time",
                description: "Average resolution time of tickets resolved in the selected time period",
                css  : ["report-arrow up negative", "report-arrow down positive"]
            },
            "AVG_FIRST_ASSIGN_TIME" : { 
                name : "AVERAGE 1ST ASSIGN TIME",
                title: "Avg 1st Assign Time",
                description: "Average first assign time of tickets assigned to agents in the selected time period",
                css  : ["report-arrow up negative", "report-arrow down positive"]
            },
            "FCR_TICKETS" : { 
                name : "FIRST CONTACT RESOLUTION",
                title: "FCR %",
                description: "The percentage of tickets that are resolved in the selected time period after the first contact made by the customer",
                css  : ["report-arrow up positive", "report-arrow down negative"]
            },
            "RESPONSE_SLA" : { 
                name : "RESPONSE SLA",
                title: "Response SLA %",
                description: "The percentage of tickets that are responded to within SLA in the selected time period",
                css  : ["report-arrow up positive", "report-arrow down negative"]
            },
            "RESOLUTION_SLA" : { 
                name : "RESOLUTION SLA",
                title: "Resolution SLA %",
                description: "The percentage of tickets that are resolved within SLA in the selected time period",
                css  : ["report-arrow up positive", "report-arrow down negative"]
            }
        },
        default_metric: "RECEIVED_TICKETS",
        report_type: "glance",
        group_by_with_status: ["source", "priority", "status", "ticket_type"],
        group_by_without_status: ["source", "priority", "ticket_type"],
        bucket_conditions: ["customer_interactions", "agent_interactions"],
        bucket_condition_metrics: ["RECEIVED_TICKETS", "RESOLVED_TICKETS", "REOPENED_TICKETS"],
        status_metrics: ["RECEIVED_TICKETS", "REOPENED_TICKETS"],
        time_metrics: ["AVG_FIRST_RESPONSE_TIME", "AVG_RESPONSE_TIME", "AVG_RESOLUTION_TIME", "AVG_FIRST_ASSIGN_TIME"],
        percentage_metrics: ["FCR_TICKETS", "RESPONSE_SLA", "RESOLUTION_SLA"],
        params: {
            bucket                : false,
            bucket_conditions     : [],
            group_by              : [],
            list                  : false,
            list_conditions       : [],
            model                 : "TICKET",
            reference             : true,
            time_trend            : false,
            time_trend_conditions : [],
            time_spent            : false,
            time_spent_conditions : []
        }
    },
    TicketVolume: {
        metrics: ["RECEIVED_RESOLVED_TICKETS"],
        metric: "RECEIVED_RESOLVED_TICKETS",
        report_type: "ticket_volume",
        params: {
            bucket                : false, 
            bucket_conditions     : [],
            group_by              : [],
            list                  : false, 
            list_conditions       : [],
            model                 : "TICKET",
            reference             : false,
            time_trend            : true, 
            time_trend_conditions : ["h", "doy", "dow", "w", "mon", "y", "qtr"], 
            time_spent            : false, 
            time_spent_conditions : []
        }
    } ,
     AgentSummary: {
        metrics: ["RESOLVED_TICKETS", "AGENT_REASSIGNED_TICKETS", "RESPONSES", "PRIVATE_NOTES",
                         "AVG_RESPONSE_TIME", "AVG_RESOLUTION_TIME", "RESPONSE_SLA", "RESOLUTION_SLA", "FCR_TICKETS", "AVG_FIRST_RESPONSE_TIME", "REOPENED_TICKETS"],
        report_type: "agent_summary",
        params: {
            bucket                : false, 
            bucket_conditions     : [],
            group_by              : ["agent_id"],
            list                  : false, 
            list_conditions       : [],
            model                 : "TICKET",
            reference             : false,
            time_trend            : false, 
            time_trend_conditions : [], 
            time_spent            : false, 
            time_spent_conditions : []
        }
    },
    GroupSummary: {
        metrics: ["RESOLVED_TICKETS", "GROUP_REASSIGNED_TICKETS", "RESPONSES", "PRIVATE_NOTES",
                         "AVG_RESPONSE_TIME", "AVG_RESOLUTION_TIME", "RESPONSE_SLA", "RESOLUTION_SLA", "FCR_TICKETS", "AVG_FIRST_RESPONSE_TIME", "REOPENED_TICKETS"],
        report_type: "group_summary",
        params: {
            bucket                : false, 
            bucket_conditions     : [],
            group_by              : ["group_id"],
            list                  : false, 
            list_conditions       : [],
            model                 : "TICKET",
            reference             : false,
            time_trend            : false, 
            time_trend_conditions : [], 
            time_spent            : false, 
            time_spent_conditions : []
        }
    },
    PerformanceDistribution: {
        metrics: ["AVG_RESPONSE_TIME","AVG_FIRST_RESPONSE_TIME","AVG_RESOLUTION_TIME"],
        bucket_conditions: ["response_time","first_response_time","resolution_time"],
        report_type: "performance_distribution",
        bucket_condition_metrics: [],
        params: {
            bucket                : false, 
            bucket_conditions     : [],
            group_by              : [],
            list                  : false, 
            list_conditions       : [],
            model                 : "TICKET",
            reference             : false,
            time_trend            : false, 
            time_trend_conditions : [],
            time_spent            : false, 
            time_spent_conditions : []
        }
    } 
}
