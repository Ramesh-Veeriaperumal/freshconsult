module HelpdeskReports
  module Constants
    module Export

      TYPES = {
        :csv => "csv",
        :pdf => "pdf",
        :xls => "xls"
      }

      TICKET_EXPORT_FIELDS = [
        "display_id",
        "subject",
        "description",
        "status_name",
        "priority_name",
        "source_name",
        "ticket_type",
        "company_name",
        "responder_name",
        "group_name",
        "requester_name",
        "requester_info",
        "requester_phone",
        "ticket_tags",
        "ticket_survey_results"
      ]

      REPORTS_NAME_MAPPING = {
        :glance                   => "Helpdesk In-depth",
        :ticket_volume            => "Ticket Volume Trends",
        :agent_summary            => "Agent Performance",
        :group_summary            => "Group Performance",
        :performance_distribution => "Performance Distribution",
        :customer_report          => "Top Customer Analysis",
        :timesheet_reports        => "Time Sheet Summary",
        :chat_summary             => "Chat Summary",
        :phone_summary            => "Phone Summary"
      }

      VIEW_HELPER_NEW_REPORTS = ['ApplicationHelper']

      VIEW_HELPER_MAPPING = { 
        glance: VIEW_HELPER_NEW_REPORTS,
        ticket_volume: VIEW_HELPER_NEW_REPORTS,
        agent_summary: VIEW_HELPER_NEW_REPORTS,
        group_summary: VIEW_HELPER_NEW_REPORTS,
        performance_distribution: VIEW_HELPER_NEW_REPORTS,
        customer_report: VIEW_HELPER_NEW_REPORTS,
        chat_summary: ['ChatHelper'],
        phone_summary: ['Reports::Freshfone::SummaryReportsHelper'],
        timesheet_reports: ['ApplicationHelper', 'Reports::TimesheetReport', 'Reports::TimesheetReportsHelper']
      }


      TICKET_EXPORT_LIMIT = 10

      TICKET_EXPORT_TYPE = "report_export/tickets"

      PDF_EXPORT_TYPE = "report_export/pdf"

      PDF_GROUP_BY_LIMIT = 11
  
      PDF_GROUP_BY_LIMITING_KEY = "-Others"
      
      REAL_TIME_REPORTS_EXPORT = false

      MAIL_ATTACHMENT_LIMIT_IN_BYTES = 10485760 # 10MB IN BYTES. 10 * 1024 * 1024 BYTES
  
      FILE_ROW_LIMITS = {
        :export => { pdf: 5000, csv: 50000 },
        :schedule => { pdf: 5000, csv: 20000 }
      }

      METRIC_TIME_TREND_KEY = {
        performance_distribution: {
          avg_resolution_time: :resolution_trend,
          avg_response_time: :response_trend,
          avg_first_response_time: :response_trend
        },
        ticket_volume: {
          received_resolved_tickets: :trend
        }
      }
    end
  end
end      
