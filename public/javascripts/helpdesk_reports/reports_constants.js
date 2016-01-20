window.HelpdeskReports = window.HelpdeskReports || {};

HelpdeskReports.Constants = {
    Glance: {
        metrics: { 
            "RECEIVED_TICKETS" : { 
                name : I18n.t('helpdesk_reports.metric_name.created_tickets'),
                title: 'helpdesk_reports.chart_title.created_tickets_group_by_chart',
                description: I18n.t('helpdesk_reports.v2_helptext.glance.created_tickets'),
                css  : ["report-arrow up negative", "report-arrow down positive"],
                bucket: ["customer_interactions", "agent_interactions"],
                bucket_graph_map: ['interactions'],
                ticket_list_title : I18n.t('helpdesk_reports.ticket_list_title.created_tickets'),
                solution_url : "https://support.freshdesk.com/support/solutions/articles/212988"
            },
            "RESOLVED_TICKETS" : { 
                name : I18n.t('helpdesk_reports.metric_name.resolved_tickets'),
                title: 'helpdesk_reports.chart_title.resolved_tickets_group_by_chart',
                description: I18n.t('helpdesk_reports.v2_helptext.glance.resolved_tickets'),
                css  : ["report-arrow up positive", "report-arrow down negative"],
                bucket: ["customer_interactions", "agent_interactions"],
                bucket_graph_map: ['interactions'],
                ticket_list_title : I18n.t('helpdesk_reports.ticket_list_title.resolved_tickets'),
                solution_url : "https://support.freshdesk.com/support/solutions/articles/212989"
            },
            "REOPENED_TICKETS" : { 
                name : I18n.t('helpdesk_reports.metric_name.reopened_tickets'),
                title: 'helpdesk_reports.chart_title.reopened_tickets_group_by_chart',
                description: I18n.t('helpdesk_reports.v2_helptext.glance.reopened_tickets'),
                css  : ["report-arrow up negative", "report-arrow down positive"],
                bucket: ["customer_interactions", "agent_interactions", "reopen_count"],
                bucket_graph_map: ['interactions', 'reopen'],
                ticket_list_title : I18n.t('helpdesk_reports.ticket_list_title.reopened_tickets'),
                solution_url : "https://support.freshdesk.com/support/solutions/articles/213067"
            },
            "AVG_FIRST_RESPONSE_TIME" : { 
                name : I18n.t('helpdesk_reports.metric_name.avg_first_response_time'),
                title: 'helpdesk_reports.chart_title.avg_first_response_time_group_by_chart',
                description: I18n.t('helpdesk_reports.v2_helptext.glance.avg_first_response_time'),
                css  : ["report-arrow up negative", "report-arrow down positive"],
                ticket_list_title : I18n.t('helpdesk_reports.ticket_list_title.avg_first_response_time'),
                solution_url : "https://support.freshdesk.com/support/solutions/articles/213074"
            },
            "AVG_RESPONSE_TIME" : { 
                name : I18n.t('helpdesk_reports.metric_name.avg_response_time'),
                title: 'helpdesk_reports.chart_title.avg_response_time_group_by_chart',
                description: I18n.t('helpdesk_reports.v2_helptext.glance.avg_response_time'),
                css  : ["report-arrow up negative", "report-arrow down positive"],
                ticket_list_title : I18n.t('helpdesk_reports.ticket_list_title.avg_response_time'),
                solution_url : "https://support.freshdesk.com/support/solutions/articles/213085"
            },
            "AVG_RESOLUTION_TIME" : { 
                name : I18n.t('helpdesk_reports.metric_name.avg_resolution_time'),
                title: 'helpdesk_reports.chart_title.avg_resolution_time_group_by_chart',
                description: I18n.t('helpdesk_reports.v2_helptext.glance.avg_resolution_time'),
                css  : ["report-arrow up negative", "report-arrow down positive"],
                ticket_list_title : I18n.t('helpdesk_reports.ticket_list_title.avg_resolution_time'),
                solution_url : "https://support.freshdesk.com/support/solutions/articles/213112"
            },
            "AVG_FIRST_ASSIGN_TIME" : { 
                name : I18n.t('helpdesk_reports.metric_name.avg_first_assign_time'),
                title: 'helpdesk_reports.chart_title.avg_first_assign_time_group_by_chart',
                description: I18n.t('helpdesk_reports.v2_helptext.glance.avg_first_assign_time'),
                css  : ["report-arrow up negative", "report-arrow down positive"],
                ticket_list_title : I18n.t('helpdesk_reports.ticket_list_title.avg_first_assign_time'),
                solution_url : "https://support.freshdesk.com/support/solutions/articles/213121"
            },
            "FCR_TICKETS" : { 
                name : I18n.t('helpdesk_reports.metric_name.fcr_tickets'),
                title: 'helpdesk_reports.chart_title.fcr_tickets_group_by_chart',
                description: I18n.t('helpdesk_reports.v2_helptext.glance.fcr_tickets'),
                css  : ["report-arrow up positive", "report-arrow down negative"],
                ticket_list_metric: 'fcr_violation',
                ticket_list_complaint_title : I18n.t('helpdesk_reports.ticket_list_title.fcr_tickets_compliant'),
                ticket_list_violated_title  : I18n.t('helpdesk_reports.ticket_list_title.fcr_tickets_violated'),
                solution_url : "https://support.freshdesk.com/support/solutions/articles/213144"
            },
            "RESPONSE_SLA" : { 
                name : I18n.t('helpdesk_reports.metric_name.first_response_sla'),
                title: 'helpdesk_reports.chart_title.first_response_sla_group_by_chart',
                description: I18n.t('helpdesk_reports.v2_helptext.glance.first_response_sla'),
                css  : ["report-arrow up positive", "report-arrow down negative"],
                ticket_list_metric: 'fr_escalated',
                ticket_list_complaint_title : I18n.t('helpdesk_reports.ticket_list_title.first_response_sla_compliant'),
                ticket_list_violated_title : I18n.t('helpdesk_reports.ticket_list_title.first_response_sla_violated'),
                solution_url : "https://support.freshdesk.com/support/solutions/articles/213166"
            },
            "RESOLUTION_SLA" : { 
                name : I18n.t('helpdesk_reports.metric_name.resolution_sla'),
                title: 'helpdesk_reports.chart_title.resolution_sla_group_by_chart',
                description: I18n.t('helpdesk_reports.v2_helptext.glance.resolution_sla'),
                css  : ["report-arrow up positive", "report-arrow down negative"],
                ticket_list_metric: 'is_escalated',
                ticket_list_complaint_title : I18n.t('helpdesk_reports.ticket_list_title.resolution_sla_compliant'),
                ticket_list_violated_title : I18n.t('helpdesk_reports.ticket_list_title.resolution_sla_violated'),
                solution_url : "https://support.freshdesk.com/support/solutions/articles/213168"
            }
        },
        template_metrics: ["GLANCE_CURRENT", "GLANCE_HISTORIC"],
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
                    'agent_interactions': I18n.t('helpdesk_reports.agent_responses'), 
                    'customer_interactions' : I18n.t('helpdesk_reports.customer_responses')
                },
                meta_data:{
                    dom_element: 'interactions',
                    legend: true,
                    xtitle: I18n.t('helpdesk_reports.chart_title.no_of_responses'),
                    ytitle: I18n.t('helpdesk_reports.chart_title.no_of_tickets'),
                    chart_height: '300',
                    title: I18n.t('helpdesk_reports.chart_title.agent_and_customer_response')
                }
            },
            reopen: {
                series: {
                    'reopen_count' : I18n.t('helpdesk_reports.reopens')
                },
                meta_data: {
                    dom_element:  'reopened_tickets',
                    legend: false,
                    xtitle: I18n.t('helpdesk_reports.chart_title.no_of_reopens'),
                    ytitle: I18n.t('helpdesk_reports.chart_title.no_of_tickets'),
                    pointWidth: 6,
                    chart_height: '275',
                    title: I18n.t('helpdesk_reports.chart_title.reopened_tickets')
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
        metrics: ["AGENT_ASSIGNED_TICKETS","RESOLVED_TICKETS","REOPENED_TICKETS", "AGENT_REASSIGNED_TICKETS", "RESPONSE_SLA", 
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
        metrics: ["GROUP_ASSIGNED_TICKETS","RESOLVED_TICKETS","REOPENED_TICKETS", "GROUP_REASSIGNED_TICKETS", "RESPONSE_SLA", 
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
                title: I18n.t('helpdesk_reports.customer_report.received_tickets'),
                description: I18n.t('helpdesk_reports.v2_helptext.customer_report.received_tickets'),
            },
            "RESOLVED_TICKETS" : { 
                title: I18n.t('helpdesk_reports.customer_report.resolved_tickets'),
                description: I18n.t('helpdesk_reports.v2_helptext.customer_report.resolved_tickets'),
            },
            "RESPONSE_VIOLATED" : { 
                title: I18n.t('helpdesk_reports.customer_report.response_violated'),
                description: I18n.t('helpdesk_reports.v2_helptext.customer_report.response_violated'),
                ticket_list_metric: 'fr_escalated'
            },
            "RESOLUTION_VIOLATED" : { 
                title: I18n.t('helpdesk_reports.customer_report.resolution_violated'),
                description: I18n.t('helpdesk_reports.v2_helptext.customer_report.resolution_violated'),
                ticket_list_metric: 'is_escalated'
            },
            "CUSTOMER_INTERACTIONS" : { 
                title: I18n.t('helpdesk_reports.customer_report.customer_interactions'),
                description: I18n.t('helpdesk_reports.v2_helptext.customer_report.customer_interactions'),
            },
            "AGENT_INTERACTIONS" : { 
                title: I18n.t('helpdesk_reports.customer_report.agent_interactions'),
                description: I18n.t('helpdesk_reports.v2_helptext.customer_report.agent_interactions'),
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
