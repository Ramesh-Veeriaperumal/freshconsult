module HelpdeskReports
  module Export
    module Constants
      
      DATA_EXPORT_TYPE = "reports"
      
                       
      TYPES = {
        :csv => "csv",
        :pdf => "pdf",
        :xls => "xls"
      }

      REPORTS_NAME_MAPPING = {
        "glance"                   => "Helpdesk In-depth",
        "ticket_volume"            => "Ticket Volume Trends",
        "agent_summary"            => "Agent Performance",
        "group_summary"            => "Group Performance",
        "performance_distribution" => "Performance Distribution",
        "customer_report"          => "Top Customer Analysis"
      }
      
    end
  end
end