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
        "glance"                   => "Helpdesk In-depth",
        "ticket_volume"            => "Ticket Volume Trends",
        "agent_summary"            => "Agent Performance",
        "group_summary"            => "Group Performance",
        "performance_distribution" => "Performance Distribution",
        "customer_report"          => "Top Customer Analysis"
      }

      TICKET_EXPORT_LIMIT = 10

      TICKET_EXPORT_TYPE = "report_export/tickets"

      PDF_EXPORT_TYPE = "report_export/pdf"

      PDF_GROUP_BY_LIMIT = 11
  
      PDF_GROUP_BY_LIMITING_KEY = "-Others"
      
      REAL_TIME_REPORTS_EXPORT = false
      
      MAIL_ATTACHMENT_LIMIT_IN_BYTES = 5 * 1024 * 1024 # 5MB

    end
  end
end
