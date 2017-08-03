module ReportsAppConfig

  def self.load_yml file
    reports_root = "config/helpdesk_reports".freeze
    YAML::load_file( File.join(Rails.root, reports_root, file) )
  end

  config = load_yml('reports_app.yml')[Rails.env]
  
  TICKET_REPORTS_URL = "#{config['host']}#{config['port']}#{config['ticket_reports']}"

  WEB_REQ_TIMEOUT = (config['web_req_timeout'] || 60).to_i

  BG_REQ_TIMEOUT  = (config['bg_req_timeout'] || 180).to_i
  
  BUCKET_QUERY = load_yml('bucket_query.yml')
  
  #Reports constraints for specific report_type/subscription_plan combination
  REPORT_CONSTRAINTS = load_yml('reports_constraints.yml').freeze

  INSIGHTS_DEFAULTS = load_yml('insights_defaults.yml').freeze

end
