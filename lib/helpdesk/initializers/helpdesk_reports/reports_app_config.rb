module ReportsAppConfig
  config = YAML::load_file(File.join(Rails.root, 'config/helpdesk_reports', 'reports_app.yml'))[Rails.env]
  
  TICKET_REPORTS_URL = "#{config['host']}#{config['port']}#{config['ticket_reports']}"
  TIMESHEET_REPORTS_URL = ""
  
  BUCKET_QUERY = YAML::load_file(File.join(Rails.root, 'config/helpdesk_reports', 'bucket_query.yml'))
  
  # Filters that are excluded for specific report_type/subscription_plan combination
  EXCLUDE_FILTERS = YAML::load_file(File.join(Rails.root, 'config/helpdesk_reports', 'exclude_filters_by_plan.yml'))
end