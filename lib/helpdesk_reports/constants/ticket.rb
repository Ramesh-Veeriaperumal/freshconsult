module HelpdeskReports::Constants::Ticket
  
  TICKET_FIELD_NAMES       = [:source, :priority, :status, :historic_status, :ticket_type, :group_id, :agent_id, :product_id, :company_id]
  
  METRIC_AND_QUERY = [
    [:RECEIVED_TICKETS,            "Count",       "Created Tickets"],
    [:RESOLVED_TICKETS,            "Count",       "Tickets Resolved"],
    [:REOPENED_TICKETS,            "Count",       "Tickets Reopened"],
    [:UNRESOLVED_TICKETS,          "Count",       "Unresolved Tickets"],
    [:AGENT_ASSIGNED_TICKETS,      "Count",       "Tickets Assigned"],
    [:GROUP_ASSIGNED_TICKETS,      "Count",       "Tickets Assigned"],
    [:AGENT_REASSIGNED_TICKETS,    "Count",       "Tickets Reassigned"],
    [:GROUP_REASSIGNED_TICKETS,    "Count",       "Tickets Reassigned"],
    [:CUSTOMER_INTERACTIONS,       "Count",       "Customer Responses"],
    [:AGENT_INTERACTIONS,          "Count",       "Agent Responses"],
    [:RESPONSE_VIOLATED,           "Count",       "Response Violated"],#Already preprocessed and returning violated % 
    [:RESOLUTION_VIOLATED,         "Count",       "Resolution Violated"],
    [:RESPONSE_SLA,                "Percentage",  "First Response SLA %"],
    [:RESOLUTION_SLA,              "Percentage",  "Resolution SLA %"],
    [:FCR_TICKETS,                 "Percentage",  "FCR %"],
    [:PRIVATE_NOTES,               "Count",       "Private Notes"],
    [:RESPONSES,                   "Count",       "Responses"],
    [:AVG_FIRST_RESPONSE_TIME,     "Avg",         "Avg 1st Response Time"],
    [:AVG_RESPONSE_TIME,           "Avg",         "Avg Response Time"],
    [:AVG_RESOLUTION_TIME,         "Avg",         "Avg Resolution Time"],
    [:AVG_FIRST_ASSIGN_TIME,       "Avg",         "Avg 1st Assign Time"],
  ]
  
  TEMPLATE_METRICS_AND_QUERY = [ :RECEIVED_RESOLVED_TICKETS, :UNRESOLVED_PREVIOUS_BENCHMARK, :UNRESOLVED_CURRENT_BENCHMARK,
                                 :RECEIVED_RESOLVED_BENCHMARK, :AGENT_SUMMARY_HISTORIC, 
                                 :AGENT_SUMMARY_CURRENT, :GROUP_SUMMARY_HISTORIC, 
                                 :GROUP_SUMMARY_CURRENT, :CUSTOMER_CURRENT_HISTORIC, 
                                 :GLANCE_CURRENT, :GLANCE_HISTORIC ]


  METRICS               = METRIC_AND_QUERY.map { |i| i[0].to_s } + TEMPLATE_METRICS_AND_QUERY.map(&:to_s)
  METRIC_TO_QUERY_TYPE  = Hash[*METRIC_AND_QUERY.map { |i| [i[0], i[1]] }.flatten]
  METRIC_TO_QUERY_TYPE.merge!({:list => "TicketList", :bucket => "Bucket" })
  
  METRIC_DISPLAY_NAME   = METRIC_AND_QUERY.map{|i| [i[0].to_s, i[2]]}.to_h

  #Mappings between redshift columns and what we use in parsing
  COLUMN_MAP = {
    :result             =>  "result",
    :benchmark          =>  "range_benchmark",
    :ticket_id          =>  "ticket_id",
    :count              =>  "count",
    :avg                =>  "avg",
    :fr_escalated       =>  "fr_escalated",
    :is_escalated       =>  "is_escalated",
    :fcr_violation      =>  "fcr_violation",
    :received_count     =>  "received_count",
    :resolved_count     =>  "resolved_count",
    :reopened_count     =>  "reopened_count",
    :received_avg       =>  "received_avg",
    :resolved_avg       =>  "resolved_avg"
  }
  
  AVOIDABLE_COLUMNS = ["h", "dow", "avg", "count", "range_benchmark", "fr_escalated",
                       "is_escalated", "fcr_violation", "resolved", "received", 
                       "received_count", "resolved_count", "received_avg", "resolved_avg","tickets_count",
                       "reopened_count", "doy_new_resolved_count", "w_new_resolved_count",
                       "mon_new_resolved_count", "qtr_new_resolved_count", "y_new_resolved_count"]
  
  DEFAULT_COLUMNS = [
    [ :agent_id,         "Agent",               :dropdown],
    [ :group_id,         "Group",               :dropdown],
    [ :ticket_type,      "Type",                :dropdown],
    [ :source,           "Source",              :dropdown],
    [ :priority,         "Priority",            :dropdown],
    [ :status,           "Status",              :dropdown],
    [ :historic_status,  "Historic Status",     :dropdown],
    [ :product_id,       "Product",             :dropdown],
    [ :company_id,       "Customer",            :dropdown]
  ]

  DEFAULT_COLUMNS_ORDER         = DEFAULT_COLUMNS.map { |i| i[0] }    
  DEFAULT_COLUMNS_OPTIONS       = Hash[*DEFAULT_COLUMNS.map { |i| [i[0], i[1]] }.flatten]
  DEFAULT_COLUMNS_KEYS_BY_TOKEN = Hash[*DEFAULT_COLUMNS.map { |i| [i[0], i[2]] }.flatten]

  REQUIRED_PARAMS = [:model, :metric, :date_range, :reference, :bucket, :time_trend, :list]
  
  FORMATTING_REQUIRED = [:glance, :agent_summary, :group_summary, :customer_report, :ticket_volume]
  
  PARAM_INCLUSION_VALUES = {
    :model       =>  ["TICKET"],
    :metric      =>  METRICS,
    :reference   =>  [true, false],
    :bucket      =>  [true, false],
    :time_trend  =>  [true, false],
    :list        =>  [true, false]   
  }
  
  common = ["RECEIVED_TICKETS", "RESOLVED_TICKETS", "REOPENED_TICKETS"]
  
  BUCKET_DIMENSIONS_TO_METRIC = {
    :customer_interactions   =>  common,
    :agent_interactions      =>  common,
    :reopen_count            =>  ["REOPENED_TICKETS"],
    :response_time           =>  ["AVG_RESPONSE_TIME"],
    :first_response_time     =>  ["AVG_FIRST_RESPONSE_TIME"],
    :resolution_time         =>  ["AVG_RESOLUTION_TIME"],
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
    "mon"       => 12,
    "qtr"       => 4
  }     
  
  DEFAULT_TIME_ZONE = "Pacific Time (US & Canada)"   

  NOT_APPICABLE = "None"
  
  NA_PLACEHOLDER_SUMMARY = "-"
  
  NA_PLACEHOLDER_GLANCE = 0
  
  TICKET_FILTER_LIMIT = 13
  
  MULTI_SELECT_LIMIT = 50
  
  TICKET_LIST_LIMIT = 25
  
  MAX_ALLOWED_DAYS = 735 # Span of 2 years

end