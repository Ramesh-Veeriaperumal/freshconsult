window.HelpdeskReports = window.HelpdeskReports || {};

HelpdeskReports.Constants = {
    Glance: {
        metrics: { 
            "RECEIVED_TICKETS" : { 
                name : "CREATED TICKETS",
                title: "Created tickets",
                description: "The tickets that were created in the helpdesk in the selected time period",
                css  : ["report-arrow up negative", "report-arrow down positive"],
                bucket: ["customer_interactions", "agent_interactions"],
                bucket_graph_map: ['interactions'],
                ticket_list_title : "All created tickets",
                solution_url : "https://support.freshdesk.com/solution/articles/212988"
            },
            "RESOLVED_TICKETS" : { 
                name : "RESOLVED TICKETS",
                title: "Resolved tickets",
                description: "The tickets resolved in the selected time period (that were created any time)",
                css  : ["report-arrow up positive", "report-arrow down negative"],
                bucket: ["customer_interactions", "agent_interactions"],
                bucket_graph_map: ['interactions'],
                ticket_list_title : "All resolved tickets",
                solution_url : "https://support.freshdesk.com/solution/articles/212989"
            },
            "REOPENED_TICKETS" : { 
                name : "REOPENED TICKETS",
                title: "Reopened tickets",
                description: "The tickets reopened in the selected time period (that were created any time)",
                css  : ["report-arrow up negative", "report-arrow down positive"],
                bucket: ["customer_interactions", "agent_interactions", "reopen_count"],
                bucket_graph_map: ['interactions', 'reopen'],
                ticket_list_title : "All reopened tickets",
                solution_url : "https://support.freshdesk.com/solution/articles/213067"
            },
            "AVG_FIRST_RESPONSE_TIME" : { 
                name : "AVERAGE 1ST RESPONSE TIME",
                title: "Avg 1st response time",
                description: "Average first response time of all the first responses made in the selected time period",
                css  : ["report-arrow up negative", "report-arrow down positive"],
                ticket_list_title : "All tickets with 1st response",
                solution_url : "https://support.freshdesk.com/solution/articles/213074"
            },
            "AVG_RESPONSE_TIME" : { 
                name : "AVERAGE RESPONSE TIME",
                title: "Avg response time",
                description: "Average response time of all the responses made in the selected time period",
                css  : ["report-arrow up negative", "report-arrow down positive"],
                ticket_list_title : "All tickets with reponse",
                solution_url : "https://support.freshdesk.com/solution/articles/213085"
            },
            "AVG_RESOLUTION_TIME" : { 
                name : "AVERAGE RESOLUTION TIME",
                title: "Avg resolution time",
                description: "Average resolution time of tickets resolved in the selected time period",
                css  : ["report-arrow up negative", "report-arrow down positive"],
                ticket_list_title : "All resolved tickets",
                solution_url : "https://support.freshdesk.com/solution/articles/213112"
            },
            "AVG_FIRST_ASSIGN_TIME" : { 
                name : "AVERAGE 1ST ASSIGN TIME",
                title: "Avg 1st assign time",
                description: "Average first assign time of tickets assigned to agents in the selected time period",
                css  : ["report-arrow up negative", "report-arrow down positive"],
                ticket_list_title : "All assigned tickets",
                solution_url : "https://support.freshdesk.com/solution/articles/213121"
            },
            "FCR_TICKETS" : { 
                name : "FIRST CONTACT RESOLUTION",
                title: "FCR %",
                description: "The percentage of tickets that were resolved after a single contact made by the customer in the selected time period",
                css  : ["report-arrow up positive", "report-arrow down negative"],
                ticket_list_metric: 'fcr_violation',
                ticket_list_complaint_title : "All FCR compliant tickets",
                ticket_list_violated_title  : "All FCR violated tickets",
                solution_url : "https://support.freshdesk.com/solution/articles/213144"
            },
            "RESPONSE_SLA" : { 
                name : "FIRST RESPONSE SLA",
                title: "First response SLA %",
                description: "The percentage of tickets whose first responses were sent within SLA in the selected time period",
                css  : ["report-arrow up positive", "report-arrow down negative"],
                ticket_list_metric: 'fr_escalated',
                ticket_list_complaint_title : "All first response SLA compliant tickets",
                ticket_list_violated_title : "All first response SLA violated tickets",
                solution_url : "https://support.freshdesk.com/solution/articles/213166"
            },
            "RESOLUTION_SLA" : { 
                name : "RESOLUTION SLA",
                title: "Resolution SLA %",
                description: "The percentage of tickets that were resolved within SLA in the selected time period",
                css  : ["report-arrow up positive", "report-arrow down negative"],
                ticket_list_metric: 'is_escalated',
                ticket_list_complaint_title : "All resolution SLA compliant tickets",
                ticket_list_violated_title : "All resolution SLA violated tickets",
                solution_url : "https://support.freshdesk.com/solution/articles/213168"
            }
        },
        default_metric: "RECEIVED_TICKETS",
        group_by_with_status: ["source", "priority", "status", "ticket_type"],
        group_by_without_status: ["source", "priority", "ticket_type"],
        group_by_extra_options: "product_id",
        reopen_bucket_condition_metrics: ["REOPENED_TICKETS"],
        interaction_bucket_condition_metrics: ["RECEIVED_TICKETS", "RESOLVED_TICKETS", "REOPENED_TICKETS"],
        bucket_condition_metrics: ["RECEIVED_TICKETS", "RESOLVED_TICKETS", "REOPENED_TICKETS"],
        status_metrics: ["RECEIVED_TICKETS", "REOPENED_TICKETS"],
        time_metrics: ["AVG_FIRST_RESPONSE_TIME", "AVG_RESPONSE_TIME", "AVG_RESOLUTION_TIME", "AVG_FIRST_ASSIGN_TIME"],
        percentage_metrics: ["FCR_TICKETS", "RESPONSE_SLA", "RESOLUTION_SLA"],
        bucket_data : {
            interactions: {
                series: {
                    'agent_interactions': 'Agent responses', 
                    'customer_interactions' : 'Customer responses'
                },
                name_series: {
                    'Agent responses': 'agent_interactions',
                    'Customer responses': 'customer_interactions'
                },
                meta_data:{
                    dom_element: 'interactions',
                    legend: true,
                    xtitle: 'No. of responses',
                    ytitle: 'No. of tickets',
                    chart_height: '300',
                    title: 'No. of agent & customer responses in '
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
                    xtitle: 'No. of reopens',
                    ytitle: 'No. of tickets',
                    pointWidth: 6,
                    chart_height: '275',
                    title: 'Reopened tickets'
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
            time_trend_conditions : []
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
            time_trend_conditions : ["h", "doy", "dow", "w", "mon", "y", "qtr"]
        }
    } ,
     AgentSummary: {
        metrics: ["RESOLVED_TICKETS","REOPENED_TICKETS", "AGENT_REASSIGNED_TICKETS", "RESPONSE_SLA", 
            "RESOLUTION_SLA", "FCR_TICKETS", "PRIVATE_NOTES", "RESPONSES", "AVG_FIRST_RESPONSE_TIME", 
            "AVG_RESPONSE_TIME", "AVG_RESOLUTION_TIME"],
        repeat: [],
        percentage_metrics: ["RESPONSE_SLA", "RESOLUTION_SLA", "FCR_TICKETS"],
        ticket_list_metrics: ["fr_escalated","is_escalated","fcr_violation"],
        time_metrics: ["AVG_FIRST_RESPONSE_TIME", "AVG_RESPONSE_TIME", "AVG_RESOLUTION_TIME"],
        template_metrics: ["AGENT_SUMMARY_CURRENT","AGENT_SUMMARY_HISTORIC"],
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
            time_trend_conditions : []
        }
    },
    GroupSummary: {
        metrics: ["RESOLVED_TICKETS","REOPENED_TICKETS", "GROUP_REASSIGNED_TICKETS", "RESPONSE_SLA", 
            "RESOLUTION_SLA", "FCR_TICKETS", "PRIVATE_NOTES", "RESPONSES", "AVG_FIRST_RESPONSE_TIME", 
            "AVG_RESPONSE_TIME", "AVG_RESOLUTION_TIME"],
        repeat: [], 
        percentage_metrics: ["RESPONSE_SLA", "RESOLUTION_SLA", "FCR_TICKETS"],
        ticket_list_metrics: ["fr_escalated","is_escalated","fcr_violation"],
        time_metrics: ["AVG_FIRST_RESPONSE_TIME", "AVG_RESPONSE_TIME", "AVG_RESOLUTION_TIME"],
        template_metrics: ["GROUP_SUMMARY_CURRENT","GROUP_SUMMARY_HISTORIC"],
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
            time_trend_conditions : []
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
            time_trend_conditions : []
        }
    },
    CustomerReport: {
        metrics: { 
            "RECEIVED_TICKETS" : { 
                title: "Tickets submitted",
                description: "The tickets that were submitted in the helpdesk in the selected time period",
            },
            "RESOLVED_TICKETS" : { 
                title: "Tickets resolved",
                description: "The tickets resolved in the selected time period (that were created any time)",
            },
            "RESPONSE_VIOLATED" : { 
                title: "Response SLA violations %",
                description: "The percentage of tickets were not responded within SLA in the selected time period",
                ticket_list_metric: 'fr_escalated'
            },
            "RESOLUTION_VIOLATED" : { 
                title: "Resolution SLA violations %",
                description: "The percentage of tickets were not resolved within SLA in the selected time period",
                ticket_list_metric: 'is_escalated'
            },
            "CUSTOMER_INTERACTIONS" : { 
                title: "Customer responses",
                description: "No. of customer responses made in the selected time period",
            },
            "AGENT_INTERACTIONS" : { 
                title: "Agent responses",
                description: "No. of agent responses made in the selected time period",
            },
        },
        report_type: "customer_report",
        percentage_metrics: ["RESPONSE_VIOLATED", "RESOLUTION_VIOLATED"],
        template_metrics: ["CUSTOMER_CURRENT_HISTORIC"],
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
            sorting               : true,             
        }
    }  
}
