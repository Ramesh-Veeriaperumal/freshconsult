module HelpdeskReports::Constants::Ticket
  
  TICEKT_FIELD_NAMES       = [:source, :priority, :status, :ticket_type, :group_id, :agent_id, :product_id, :company_id]
  
  METRIC_AND_QUERY = [
    [:RECEIVED_TICKETS,            "Count"],
    [:RESOLVED_TICKETS,            "Count"],
    [:REOPENED_TICKETS,            "Count"],
    [:AGENT_ASSIGNED_TICKETS,      "Count"],
    [:GROUP_ASSIGNED_TICKETS,      "Count"],
    [:AGENT_REASSIGNED_TICKETS,    "Count"],
    [:GROUP_REASSIGNED_TICKETS,    "Count"],
    [:RESPONSES,                   "Count"],
    [:PRIVATE_NOTES,               "Count"],
    [:CUSTOMER_INTERACTIONS,       "Count"],
    [:AGENT_INTERACTIONS,          "Count"],
    [:RESPONSE_VIOLATED,           "Count"],#Already preprocessed and returning violated % 
    [:RESOLUTION_VIOLATED,         "Count"],
    [:AVG_FIRST_RESPONSE_TIME,     "Avg"],
    [:AVG_RESPONSE_TIME,           "Avg"],
    [:AVG_RESOLUTION_TIME,         "Avg"],
    [:AVG_FIRST_ASSIGN_TIME,       "Avg"],
    [:RESPONSE_SLA,                "Percentage"],
    [:RESOLUTION_SLA,              "Percentage"],
    [:FCR_TICKETS,                 "Percentage"],
    [:RECEIVED_RESOLVED_TICKETS,   "TicketVolume"]
  ]
  
  METRICS               = METRIC_AND_QUERY.map { |i| i[0].to_s }
  METRIC_TO_QUERY_TYPE  = Hash[*METRIC_AND_QUERY.map { |i| [i[0], i[1]] }.flatten]
  METRIC_TO_QUERY_TYPE.merge!({:list => "TicketList", :bucket => "Bucket" })

  #Mappings between redshift columns and what we use in parsing
  COLUMN_MAP = {
    :result           =>  "result",
    :benchmark        =>  "range_benchmark",
    :ticket_id        =>  "ticket_id",
    :count            =>  "count",
    :avg              =>  "avg",
    :fr_escalated     =>  "fr_escalated",
    :is_escalated     =>  "is_escalated",
    :fcr_violation    =>  "fcr_violation",
    :received_count   =>  "received_count",
    :resolved_count   =>  "resolved_count",
    :received_avg     =>  "received_avg",
    :resolved_avg     =>  "resolved_avg"
  }
  
  AVOIDABLE_COLUMNS = ["h", "dow", "avg", "count", "range_benchmark", "fr_escalated",
                       "is_escalated", "fcr_violation", "resolved", "received", 
                       "received_count", "resolved_count", "received_avg", "resolved_avg","tickets_count"]
  
  DEFAULT_COLUMNS = [
    [ :agent_id,       "Agent",      :dropdown],
    [ :group_id,       "Group",      :dropdown],
    [ :ticket_type,    "Type",       :dropdown],
    [ :source,         "Source",     :dropdown],
    [ :priority,       "Priority",   :dropdown],
    [ :status,         "Status",     :dropdown],
    [ :product_id,     "Product",    :dropdown],
    [ :company_id,     "Customer",   :dropdown]
  ]

  DEFAULT_COLUMNS_ORDER         = DEFAULT_COLUMNS.map { |i| i[0] }    
  DEFAULT_COLUMNS_OPTIONS       = Hash[*DEFAULT_COLUMNS.map { |i| [i[0], i[1]] }.flatten]
  DEFAULT_COLUMNS_KEYS_BY_TOKEN = Hash[*DEFAULT_COLUMNS.map { |i| [i[0], i[2]] }.flatten]

  REPORT_TYPE = [
    [ :GLANCE,                       101],
    [ :TICKET_VOLUME,                102],
    [ :PERFORMANCE_DISTRIBUTION,     104],
    [ :AGENT_SUMMARY,                105],
    [ :GROUP_SUMMARY,                106],
    # [ :CUSTOMER_REPORT,              107]
  ]
  
  REPORT_TYPE_BY_NAME = REPORT_TYPE.map { |i| i[0].to_s.downcase }   
  REPORT_TYPE_BY_KEY  = Hash[*REPORT_TYPE.map { |i| [i[0], i[1]] }.flatten]
  
  DEFAULT_REPORTS     = ["agent_summary", "group_summary"]
  ADVANCED_REPORTS    = DEFAULT_REPORTS + ["glance"]
  ENTERPRISE_REPORTS  = ADVANCED_REPORTS + ["ticket_volume", "performance_distribution","customer_report"] 

  REPORT_ARTICAL_LINKS = {
    :HELPDESK_GLANCE           => '',
    :TICKET_VOLUME             => '',
    :PERFORMANCE               => '',
    :PERFORMANCE_DISTRIBUTION  => '',
    :AGENT_SUMMARY             => '',
    :GROUP_SUMMARY             => '',
  }

  REQUIRED_PARAMS = [:model, :metric, :date_range, :reference, :bucket, :time_trend, :time_spent, :list]
  
  # REPORTS_COMPLETED = [:glance, :ticket_volume, :agent_summary, :group_summary, :performance_distribution, :customer_report]
  REPORTS_COMPLETED = [:glance, :ticket_volume, :agent_summary, :group_summary, :performance_distribution]

  FORMATTING_REQUIRED = [:glance, :agent_summary, :group_summary, :customer_report]
  
  PARAM_INCLUSION_VALUES = {
    :model       =>  ["TICKET"],
    :metric      =>  METRICS,
    :reference   =>  [true, false],
    :bucket      =>  [true, false],
    :time_trend  =>  [true, false],
    :time_spent  =>  [true, false],
    :list        =>  [true, false]   
  }
  
  common = ["RECEIVED_TICKETS", "RESOLVED_TICKETS", "REOPENED_TICKETS", "FCR_TICKETS"]
  
  BUCKET_DIMENSIONS_TO_METRIC = {
    :customer_interactions   =>  common,
    :agent_interactions      =>  common,
    :agent_reassign_count    =>  common,
    :group_reassign_count    =>  common,
    :reopen_count            =>  common,
    :response_time           =>  ["AVG_RESPONSE_TIME"],
    :first_response_time     =>  ["AVG_FIRST_RESPONSE_TIME"],
    :resolution_time         =>  ["AVG_RESOLUTION_TIME"],
    :reply_count             =>  ["REPLIES"],
    :private_note_count      =>  ["PRIVATE_NOTES"]
  }
  
  TRENDS = [
    ["h",     1000000], # Arbitrary large value to make sure
    ["dow",   1000000], # "h" & "dow" are always present in trend_conditons
    ["doy",        31],
    ["w",        7*31],
    ["mon",     30*31],
    ["qtr",   3*30*31],
    ["y",      365*31]
  ]
  TIME_TREND = TRENDS.map { |i| i[0] }
  
  # To limit trend graphs for particualr trend based on duration selected
  # eg, disable doy if duration > 31 days, disable week if duration > 217 days
  MAX_DATE_RANGE_FOR_TREND  = Hash[*TRENDS.map { |i| [i[0], i[1]] }.flatten]
  
  TREND_MAX_VALUE = {
    "leap_year" => 366,
    "year"      => 365,
    "w"         => 52,
    "mon"       => 12,
    "qtr"       => 4
  }     
  
  # Constraint on date_range by subscription plan (Restrict query to x days from today)
  DATE_LAG_CONSTRAINT = {
    "Sprout"  => 1,
    "Blossom" => 1,
    "Garden"  => 1,
    "Estate"  => 0,
    "Forest"  => 0
  }

  DEFAULT_TIME_ZONE = "Pacific Time (US & Canada)"   

  NOT_APPICABLE = "NA"
  
  NA_PLACEHOLDER_SUMMARY = "-"
  
  NA_PLACEHOLDER_GLANCE = 0
  
  TICKET_FILTER_LIMIT = 5
  
  MULTI_SELECT_LIMIT = 10
  
  TICKET_LIST_LIMIT = 25
end