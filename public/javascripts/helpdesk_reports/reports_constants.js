window.HelpdeskReports = window.HelpdeskReports || {};

HelpdeskReports.Constants = {
    Glance: {
        metrics: { 
            "RECEIVED_TICKETS" : { 
                name : "CREATED TICKETS",
                title: "Created Tickets",
                description: "The tickets that were created in the helpdesk in the selected time period",
                css  : ["report-arrow up negative", "report-arrow down positive"],
                bucket: ["customer_interactions", "agent_interactions"],
                bucket_graph_map: ['interactions'],
            },
            "RESOLVED_TICKETS" : { 
                name : "RESOLVED TICKETS",
                title: "Resolved Tickets",
                description: "The tickets resolved in the selected time period (that were created any time)",
                css  : ["report-arrow up positive", "report-arrow down negative"],
                bucket: ["customer_interactions", "agent_interactions"],
                bucket_graph_map: ['interactions'],
            },
            "REOPENED_TICKETS" : { 
                name : "REOPENED TICKETS",
                title: "Reopened Tickets",
                description: "The tickets reopened in the selected time period (that were created any time)",
                css  : ["report-arrow up negative", "report-arrow down positive"],
                bucket: ["customer_interactions", "agent_interactions", "reopen_count"],
                bucket_graph_map: ['interactions', 'reopen'],
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
                description: "The percentage of tickets that were resolved after a single contact made by the customer in the selected time period",
                css  : ["report-arrow up positive", "report-arrow down negative"],
                ticket_list_metric: 'fcr_violation'
            },
            "RESPONSE_SLA" : { 
                name : "FIRST RESPONSE SLA",
                title: "First Response SLA %",
                description: "The percentage of tickets whose first responses were sent within SLA in the selected time period",
                css  : ["report-arrow up positive", "report-arrow down negative"],
                ticket_list_metric: 'fr_escalated'
            },
            "RESOLUTION_SLA" : { 
                name : "RESOLUTION SLA",
                title: "Resolution SLA %",
                description: "The percentage of tickets that were resolved within SLA in the selected time period",
                css  : ["report-arrow up positive", "report-arrow down negative"],
                ticket_list_metric: 'is_escalated'
            }
        },
        default_metric: "RECEIVED_TICKETS",
        group_by_with_status: ["source", "priority", "status", "ticket_type"],
        group_by_without_status: ["source", "priority", "ticket_type"],
        reopen_bucket_condition_metrics: ["REOPENED_TICKETS"],
        interaction_bucket_condition_metrics: ["RECEIVED_TICKETS", "RESOLVED_TICKETS", "REOPENED_TICKETS"],
        bucket_condition_metrics: ["RECEIVED_TICKETS", "RESOLVED_TICKETS", "REOPENED_TICKETS"],
        status_metrics: ["RECEIVED_TICKETS", "REOPENED_TICKETS"],
        time_metrics: ["AVG_FIRST_RESPONSE_TIME", "AVG_RESPONSE_TIME", "AVG_RESOLUTION_TIME", "AVG_FIRST_ASSIGN_TIME"],
        percentage_metrics: ["FCR_TICKETS", "RESPONSE_SLA", "RESOLUTION_SLA"],
        bucket_data : {
            interactions: {
                series: {
                    'agent_interactions': 'Agent Responses', 
                    'customer_interactions' : 'Customer Responses'
                },
                name_series: {
                    'Agent Responses': 'agent_interactions',
                    'Customer Responses': 'customer_interactions'
                },
                meta_data:{
                    dom_element: 'interactions',
                    legend: true,
                    xtitle: 'No. of Responses',
                    ytitle: 'No. of Tickets',
                    chart_height: '300',
                    title: 'Agent & Customer Responses'
                }
            },
            reopen: {
                series: {
                    'reopen_count' : 'Reopens'
                },
                name_series: {
                    'Reopens': 'reopen_count'
                },
                meta_data: {
                    dom_element:  'reopened_tickets',
                    legend: false,
                    xtitle: 'No. of Reopens',
                    ytitle: 'No. of Tickets',
                    pointWidth: 6,
                    chart_height: '275',
                    title: 'Reopened Tickets'
                }
            }
        },
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
        metrics: ["RESOLVED_TICKETS","REOPENED_TICKETS", "AGENT_REASSIGNED_TICKETS", "RESPONSE_SLA", 
            "RESOLUTION_SLA", "FCR_TICKETS", "PRIVATE_NOTES", "RESPONSES", "AVG_FIRST_RESPONSE_TIME", 
            "AVG_RESPONSE_TIME", "AVG_RESOLUTION_TIME"],
        repeat: ["FCR_TICKETS"],
        percentage_metrics: ["RESPONSE_SLA", "RESOLUTION_SLA", "FCR_TICKETS"],
        ticket_list_metric: ["fr_escalated","is_escalated","fcr_violation"],
        time_metrics: ["AVG_FIRST_RESPONSE_TIME", "AVG_RESPONSE_TIME", "AVG_RESOLUTION_TIME"],
        group_by: "agent_id",
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
    },
    GroupSummary: {
        metrics: ["RESOLVED_TICKETS","REOPENED_TICKETS", "GROUP_REASSIGNED_TICKETS", "RESPONSE_SLA", 
            "RESOLUTION_SLA", "FCR_TICKETS", "PRIVATE_NOTES", "RESPONSES", "AVG_FIRST_RESPONSE_TIME", 
            "AVG_RESPONSE_TIME", "AVG_RESOLUTION_TIME"],
        repeat: ["FCR_TICKETS"], 
        percentage_metrics: ["RESPONSE_SLA", "RESOLUTION_SLA", "FCR_TICKETS"],
        ticket_list_metric: ["fr_escalated","is_escalated","fcr_violation"],
        time_metrics: ["AVG_FIRST_RESPONSE_TIME", "AVG_RESPONSE_TIME", "AVG_RESOLUTION_TIME"],
        group_by: 'group_id',
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
    },
    PerformanceDistribution: {
        metrics: ["AVG_RESPONSE_TIME","AVG_FIRST_RESPONSE_TIME","AVG_RESOLUTION_TIME"],
        bucket_conditions: ["response_time","first_response_time","resolution_time"],
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
    },
    CustomerReport: {
        metrics: { 
            "RECEIVED_TICKETS" : { 
                title: "Tickets Submitted",
                description: "The tickets that were submitted in the helpdesk in the selected time period",
            },
            "RESOLVED_TICKETS" : { 
                title: "Tickets Resolved",
                description: "The tickets resolved in the selected time period (that were created any time)",
            },
            "RESPONSE_VIOLATED" : { 
                title: "Response SLA Violations %",
                description: "The percentage of tickets whose first responses were violated within SLA in the selected time period",
                ticket_list_metric: 'fr_escalated'
            },
            "RESOLUTION_VIOLATED" : { 
                title: "Resolution SLA Violations %",
                description: "The percentage of tickets that weren't resolved within SLA in the selected time period",
                ticket_list_metric: 'is_escalated'
            },
            "CUSTOMER_INTERACTIONS" : { 
                title: "Customer Responses",
                description: "No. of customer responses made in the selected time period",
            },
            "AGENT_INTERACTIONS" : { 
                title: "Agent Responses",
                description: "No. of agent responses made in the selected time period",
            },
        },
        report_type: "customer_report",
        percentage_metrics: ["RESPONSE_VIOLATED", "RESOLUTION_VIOLATED"],
        params: {
            bucket                : false, 
            bucket_conditions     : [],
            group_by              : ["company_id"],
            list                  : false, 
            list_conditions       : [],
            model                 : "TICKET",
            reference             : false,
            time_trend            : false, 
            time_trend_conditions : [],
            time_spent            : false, 
            time_spent_conditions : [],
            sorting               : true,             
        }
    }  
}
