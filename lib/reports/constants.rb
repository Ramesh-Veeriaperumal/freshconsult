module Reports
	module Constants

    DEFAULT_TICKET_COLUMNS = ['ticket_type', 'priority', 'source', 'status', 'account_id', 'requester_id',
                              'responder_id', 'group_id']
    DEFAULT_SCHEMA_LESS_TICKET_COLUMNS = ['product_id', "#{Helpdesk::SchemaLessTicket.survey_rating_column}"]
    USER_COLUMNS = ['customer_id']
    STATS_COLUMNS = ['created_hour', 'resolved_hour']
    AGGREGATE_COLUMNS = ['received_tickets','resolved_tickets','backlog_tickets','avg_resp_time',
        'avg_resp_time_by_bhrs','first_responded_tickets','first_resp_time','first_resp_time_by_bhrs',
        'resolution_time','resolution_time_by_bhrs','customer_interactions','agent_interactions',
        'num_of_reopens','assigned_tickets','num_of_reassigns','fcr_tickets','sla_tickets',
        'happy_rated_tickets','neutral_rated_tickets','unhappy_rated_tickets']
    ALL_FF_COLUMNS = (1..30).inject([]) {|r, n| n > 9 ? r << "ffs_#{n}" : r << "ffs_0#{n}"}

    REPORT_COLUMNS = AGGREGATE_COLUMNS + DEFAULT_TICKET_COLUMNS + DEFAULT_SCHEMA_LESS_TICKET_COLUMNS +
                      USER_COLUMNS + STATS_COLUMNS + ALL_FF_COLUMNS
    REDSHIFT_MODIFIED_COLUMNS = { "#{Helpdesk::SchemaLessTicket.survey_rating_column}" => "survey_rating"}
    REDSHIFT_COLUMNS = REPORT_COLUMNS.map {|c| REDSHIFT_MODIFIED_COLUMNS.key?(c) ? REDSHIFT_MODIFIED_COLUMNS[c] : c } + %w(created_at)
    
    CSV_FILE_DIR = File.join("#{RAILS_ROOT}","tmp","files")
    ARCHIVE_DATA_FILE = "%{date}_account_%{account_id}"

    DEFAULT_COLUMNS_ORDER = [:responder_id, :group_id,:customer_id, :priority,:ticket_type,:source,:product_id]
    ACTIVITY_GROUPBY_ARRAY = ['ticket_type','source','priority']

    REPORTS_TABLE = 'helpdesk_report_stats'
    REPORTS_DATE_COLUMN = 'created_at'

    DEFAULT_COLUMNS =  [
      [ :responder_id,        "Agent",    :dropdown],
      [ :group_id,            "Group",    :dropdown],
      [ :ticket_type,         "Type",     :dropdown],
      [ :source,              "Source",   :dropdown],
      [ :priority,            "Priority", :dropdown],
      [ :product_id,          "Product",  :dropdown],
      [ :customer_id,         "Customer", :dropdown]
    ]
    
    DEFAULT_COLUMNS_OPTIONS = Hash[*DEFAULT_COLUMNS.map { |i| [i[0], i[1]] }.flatten]
    DEFAULT_COLUMNS_BY_KEY = Hash[*DEFAULT_COLUMNS.map { |i| [i[2], i[1]] }.flatten]
    DEFAULT_COLUMNS_KEYS_BY_TOKEN = Hash[*DEFAULT_COLUMNS.map { |i| [i[0], i[2]] }.flatten]

    COMPARISON_FIELDS =[
      [:assigned_tickets,       'adv_reports.comparison_reports.ticket_assigned',     'adv_reports.comparison_reports.label_num_of_tickets'],
      [:resolved_tickets,       'adv_reports.tickets_resolved',                       'adv_reports.comparison_reports.label_num_of_tickets'],
      [:backlog_tickets,        'adv_reports.tickets_backlog',                        'adv_reports.comparison_reports.label_num_of_tickets'],
      [:num_of_reopens,         'adv_reports.glance.num_of_reopens',                  'adv_reports.glance.num_of_reopens'],
      [:fcr_tickets,            'reports.summary_report.fcr_percent',                 'adv_reports.comparison_reports.label_in_percentage'],
      [:sla_tickets,            'adv_reports.glance.sla_percentage',                  'adv_reports.comparison_reports.label_in_percentage'],
      [:avg_agent_interactions, 'adv_reports.glance.avg_agent_intr',                  'adv_reports.comparison_reports.label_num_of_interactions'],
      [:avg_resolution_time,    'adv_reports.comparison_reports.avg_resolution_time', 'adv_reports.comparison_reports.label_in_hrs'],
      [:avg_first_response_time,'adv_reports.comparison_reports.avg_first_resp_time', 'adv_reports.comparison_reports.label_in_hrs'],
      [:avg_response_time,      'adv_reports.comparison_reports.avg_resp_time',       'adv_reports.comparison_reports.label_in_hrs']
    ]
    COMPARISON_FIELDS_OPTIONS = Hash[*COMPARISON_FIELDS.map { |i| [i[0], i[1]] }.flatten]
    COMPARISON_FIELDS_KEYS_BY_TOKEN = Hash[*COMPARISON_FIELDS.map { |i| [i[0], i[2]] }.flatten]
    COMPARISON_PERCENTAGE_FIELDS = [:fcr_tickets,:sla_tickets]
    # Timezones with Time Mapping in UTC
    # List of Countries in which Time falls to midnight at 0th,1st,2nd .... hour in UTC

    TIMEZONES_BY_UTC_TIME = {
      "0" => ["Casablanca","Dublin","Edinburgh","Lisbon","London","Monrovia","UTC","Europe/London"],
      "1" => ["Azores","Cape Verde Is."],
      "2" => ["Mid-Atlantic"],
      "3" => ["Brasilia","Buenos Aires","Georgetown","Greenland"],
      "4" => ["Newfoundland","Atlantic Time (Canada)","La Paz","Santiago"],
      "5" => ["Caracas","Bogota","America/Bogota","Eastern Time (US & Canada)","Indiana (East)","Lima","Quito"],
      "6" => ["Central America","Central Time (US & Canada)","Guadalajara","Mexico City","Monterrey",
               "Saskatchewan","America/Chicago"],
      "7" => ["Arizona","Chihuahua","Mazatlan","Mountain Time (US & Canada)"],
      "8" => ["Pacific Time (US & Canada)","Tijuana", "America/Los_Angeles"],
      "9" => ["Alaska"],
      "10" => ["Hawaii"],
      "11" => ["International Date Line West","Midway Island","Samoa","Nuku'alofa"],
      "12" => ["Auckland","Fiji","Kamchatka","Marshall Is.","Wellington"],
      "13" => ["Magadan","New Caledonia","Solomon Is."],
      "14" => ["Brisbane","Canberra","Guam","Hobart","Melbourne","Port Moresby","Sydney","Vladivostok"],
      "15" => ["Adelaide","Darwin","Osaka","Sapporo","Seoul","Tokyo","Yakutsk"],
      "16" => ["Beijing","Chongqing","Hong Kong","Irkutsk","Kuala Lumpur","Perth","Singapore",
               "Taipei","Ulaan Bataar","Urumqi"],
      "17" => ["Bangkok","Hanoi","Jakarta","Krasnoyarsk"],
      "18" => ["Rangoon","Almaty","Astana","Dhaka","Novosibirsk"],
      "19" => ["Kathmandu","Chennai","Kolkata","Mumbai","New Delhi","Sri Jayawardenepura",
               "Ekaterinburg","Islamabad","Karachi","Tashkent"],
      "20" => ["Kabul","Abu Dhabi","Baku","Muscat","Tbilisi","Yerevan"],
      "21" => ["Tehran","Baghdad","Kuwait","Moscow","Nairobi","Riyadh","St. Petersburg","Volgograd"],
      "22" => ["Athens","Bucharest","Cairo","Harare","Helsinki","Istanbul","Jerusalem","Kyev","Minsk",
               "Pretoria","Riga","Sofia","Tallinn","Vilnius"],
      "23" => ["Amsterdam","Belgrade","Berlin","Bern","Bratislava","Brussels","Budapest","Copenhagen",
               "Ljubljana","Madrid","Paris","Prague","Rome","Sarajevo","Skopje","Stockholm","Vienna",
               "Warsaw","West Central Africa","Zagreb"]
    }
   
    TOP_N_ANALYSIS_COLUMNS = [
      {:id => 'resolved_tickets' ,:label_name => I18n.t('adv_reports.tickets_resolved'),:calculate_percent =>false, 
       :order => 'DESC', :count_column => 'resolved_tickets', :selet_columns => 'resolved_tickets',:is_rating=>false},
      {:id => 'backlog_tickets' ,:label_name => I18n.t('adv_reports.tickets_backlog'),:calculate_percent =>false, 
       :order => 'DESC', :count_column => 'backlog_tickets',:selet_columns => 'backlog_tickets',:is_rating=>false},
      {:id => 'FCR_tickets' ,:label_name => I18n.t('reports.summary.fcr'),:calculate_percent =>true, 
       :order => 'DESC', :count_column => 'fcr_tickets',:selet_columns => 'fcr_tickets_percentage',:is_rating=>false},
      {:id => 'SLA_DESC_tickets' ,:label_name => I18n.t('reports.summary.sla_compliance'),:calculate_percent =>true, 
       :order => 'DESC', :count_column => 'sla_tickets',:selet_columns => 'sla_tickets_percentage',:is_rating=>false},
      {:id => 'avg_response_time' ,:label_name => I18n.t('adv_reports.comparison_reports.avg_resp_time'),:is_time_column => true,
       :order => 'DESC', :count_column => 'avgresponsetime',:selet_columns => 'avg_response_time_per_ticket'},
      {:id => 'avg_first_response_time' ,:label_name => I18n.t('adv_reports.comparison_reports.avg_first_resp_time'), :is_time_column=> true,
       :order => 'DESC', :count_column => 'avgfirstresptime',:selet_columns => 'avg_first_resp_time_per_ticket'},
      {:id => 'avg_resolution_time' ,:label_name => I18n.t('adv_reports.comparison_reports.avg_resolution_time'), :is_time_column=>true,
       :order => 'DESC', :count_column => 'avgresolutiontime',:selet_columns => 'avg_resolution_time_per_ticket'},
      {:id => 'avg_agent_interactions' ,:label_name => I18n.t('adv_reports.glance.avg_agent_intr'),
       :order => 'DESC', :count_column => 'avgagentinteractions',:selet_columns => 'avg_agent_interactions_per_ticket'},
      {:id => 'assigned_tickets' ,:label_name => I18n.t('adv_reports.comparison_reports.ticket_assigned'), 
       :order => 'DESC', :count_column => 'assigned_tickets',:selet_columns => 'assigned_tickets'},
      {:id => 'num_of_reopens' ,:label_name => I18n.t('adv_reports.glance.num_of_reopens'), 
       :order => 'DESC', :count_column => 'num_of_reopens',:selet_columns => 'num_of_reopens'},
      {:id => 'happy_customers' ,:label_name => I18n.t('adv_reports.top_n.happy_customers'),:calculate_percent =>true, 
       :order => 'DESC', :count_column => 'happy_customers',:selet_columns => 'happy_customers',:is_rating=>true}
    ]
    
    AJAX_TOP_N_ANALYSIS_COLUMNS = TOP_N_ANALYSIS_COLUMNS.inject({}) do |r, h| 
      r[h[:id]] = h
      r
    end

    CUSTOMERS_TOP_N_ANALYSIS_COLUMNS = [
      {:id => 'resolved_tickets' ,:label_name => I18n.t('adv_reports.tickets_resolved'),:calculate_percent =>false, 
       :order => 'DESC', :count_column => 'resolved_tickets',:selet_columns => 'resolved_tickets',:is_rating=>false},
      {:id => 'backlog_tickets' ,:label_name => I18n.t('adv_reports.tickets_backlog'),:calculate_percent =>false, 
       :order => 'DESC', :count_column => 'backlog_tickets',:selet_columns => 'backlog_tickets',:is_rating=>false},
      {:id => 'received_tickets' ,:label_name => I18n.t('adv_reports.top_n.tickets_submitted'),:calculate_percent =>false, 
       :order => 'DESC', :count_column => 'received_tickets',:selet_columns => 'received_tickets',:is_rating=>false},
      {:id => 'SLA_tickets' ,:label_name => I18n.t('adv_reports.top_n.sla_violations'),:calculate_percent =>true, 
       :order => 'DESC', :count_column => 'sla_tickets',:selet_columns => 'sla_violation_tickets',:is_rating=>false},
      {:id => 'happy_customers' ,:label_name => I18n.t('adv_reports.top_n.happy_customers'),:calculate_percent =>true, 
       :order => 'DESC', :count_column => 'happy_customers',:selet_columns => 'happy_customers',:is_rating=>true},
      {:id => 'frustrated_customers' ,:label_name => I18n.t('adv_reports.top_n.frustrated_customers'),:calculate_percent =>true, 
       :order => 'DESC', :count_column => 'frustrated_customers',:selet_columns => 'frustrated_customers',:is_rating=>true},
      {:id => 'avg_response_time' ,:label_name => I18n.t('adv_reports.comparison_reports.avg_resp_time'), :is_time_column=>true,
       :order => 'DESC', :count_column => 'avgresponsetime',:selet_columns => 'avg_response_time_per_ticket'},
      {:id => 'FCR_tickets' ,:label_name => I18n.t('reports.summary.fcr'),:calculate_percent =>true, 
       :order => 'DESC', :count_column => 'fcr_tickets',:selet_columns => 'fcr_tickets_percentage',:is_rating=>false},
      {:id => 'avg_first_response_time' ,:label_name => I18n.t('adv_reports.comparison_reports.avg_first_resp_time'),:is_time_column=>true, 
       :order => 'DESC', :count_column => 'avgfirstresptime',:selet_columns => 'avg_first_resp_time_per_ticket'},
      {:id => 'avg_resolution_time' ,:label_name => I18n.t('adv_reports.comparison_reports.avg_resolution_time'), :is_time_column=>true,
       :order => 'DESC', :count_column => 'avgresolutiontime',:selet_columns => 'avg_resolution_time_per_ticket'},
      {:id => 'avg_customer_interactions' ,:label_name => I18n.t('adv_reports.glance.avg_cust_intr'), 
       :order => 'DESC', :count_column => 'avgcustomerinteractions',:selet_columns => 'avg_customer_interactions_per_ticket'}
    ]

    AJAX_CUSTOMERS_TOP_N_ANALYSIS_COLUMNS = CUSTOMERS_TOP_N_ANALYSIS_COLUMNS.inject({}) do |r, h| 
      r[h[:id]] = h
      r
    end

    def self.comparison_metrics
      Hash[*COMPARISON_FIELDS.map { |i| [i[0], I18n.t(i[1])] }.flatten]
    end
    
    def self.comparison_metrics_labels
      Hash[*COMPARISON_FIELDS.map { |i| [i[0], I18n.t(i[2])] }.flatten]
    end

    REPORT_TYPE =  [
      [ :helpdesk_glance,              101],
      [ :customer_glance,              102],
      [ :agent_glance,                 103],
      [ :group_glance,                 104],
      [ :agent_analysis,               201],
      [ :group_analysis,               202],
      [ :customer_analysis,            203],
      [ :helpdesk_peformance_analysis, 204],
      [ :helpdesk_load_analysis,       205],            
      [ :agent_comparison,             301],            
      [ :group_comparison,             302]
    ]
    
    REPORT_TYPE_BY_KEY = Hash[*REPORT_TYPE.map { |i| [i[0], i[1]] }.flatten]

    REPORT_ARTICAL_LINKS ={
      :agent_top_n_analysis         => 'https://support.freshdesk.com/solution/categories/45929/folders/145570/articles/85344-how-to-read-agent-top-n-analysis',
      :customer_top_n_analysis      => 'https://support.freshdesk.com/solution/categories/45929/folders/145570/articles/85346-how-to-read-customer-top-n-analysis',
      :group_top_n_analysis         => 'https://support.freshdesk.com/solution/categories/45929/folders/145570/articles/85345-how-to-read-group-top-n-analysis',
      :helpdesk_glance_report       => 'https://support.freshdesk.com/solution/categories/45929/folders/145570/articles/85335-how-to-read-helpdesk-at-a-glance-report',
      :customer_glance_report       => 'https://support.freshdesk.com/solution/categories/45929/folders/145570/articles/85336-how-to-read-customer-at-a-glance-report',
      :agent_glance_report          => 'https://support.freshdesk.com/solution/categories/45929/folders/145570/articles/85337-how-to-read-agent-at-a-glance-report',
      :group_glance_report          => 'https://support.freshdesk.com/solution/categories/45929/folders/145570/articles/85338-how-to-read-group-at-a-glance-report',
      :helpdesk_peformance_analysis => 'https://support.freshdesk.com/solution/categories/45929/folders/145570/articles/85343-how-to-read-helpdesk-performance-analysis-report',
      :helpdesk_load_analysis       => 'https://support.freshdesk.com/solution/categories/45929/folders/145570/articles/85340-how-to-read-helpdesk-load-analysis-report'    
    }

    REPORTS_GLANCE_TICKET_VIEW = {
      :helpdesk  => [:helpdesk_received, :helpdesk_resolved],
      :group     => [:group_received, :group_resolved],
      :agent     => [:agent_received, :agent_resolved],
      :customer  => [:customer_received, :customer_resolved]
    }

	end
end