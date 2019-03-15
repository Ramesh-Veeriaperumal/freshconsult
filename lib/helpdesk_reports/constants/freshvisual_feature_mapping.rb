# A map of Freshdesk bitmap features with their corresponding Features in FreshVisuals.
module HelpdeskReports::Constants::FreshvisualFeatureMapping
  CONFIG_TYPES = {
    FEATURE_CONFIGS: :feature_config,
    CURATED_REPORTS: :curated_reports,
    RESOURCE_RESTRICTIONS: :resource_restriction
  }.freeze

  # Config payload list maintained in FreshVisuals.
  # We maintain Bitmap features for each of these configs. And for the respective BM feature we will map the corresponding FV features.
  # Refer: https://confluence.freshworks.com/pages/viewpage.action?spaceKey=freshvisuals&title=Pricing+Plan+based+Restriction for the correct configuration.
  # If Freshvisuals intimates us for any changes. Add that in the following payload, Add a bitmap feature and do the FD_FRESVISUAL_FEATURE_MAPPING mapping below.
  config_payload = {
    featureConfig: {
      pages: {
        landing: { search: false, dataSchedules: false, newReport: false, navigation: true, NLP: false },
        report: { clone: false, filter: false, schedule: false, export: false, presentationMode: false, delete: false, save: false, searchWidget: false, addWidgets: false },
        widget: { schedule: false, export: false, save: false, saveAs: false, addToReports: false, changeChart: false, filter: false, showTabularData: false, editTabularData: false, delete: false }
      }
    }
  }

  CONFIG_PAYLOAD = config_payload.to_json.freeze

  # FEATURE_CONFIGS => {:landing_search=>{:config_type=>:feature_config, :report_type=>:landing, :value=>:search}, :landing_data_schedules=>{:config_type=>:feature_config, :report_type=>:landing, :value=>:dataSchedules}, ...}
  FEATURE_CONFIGS = config_payload[:featureConfig].map do |_, report_types|
    report_types.map do |type, features|
      Hash[features.keys.map do |feature|
             ["#{type}_#{feature.to_s.snakecase}".to_sym, { config_type: :feature_config, report_type: type, value: feature }]
           end]
    end.reduce(&:merge)
  end.reduce(&:merge)

  # Curated reports list maintained in Freshvisuals.
  CURATED_REPORTS_LIST = ['Agent performance', 'Group performance', 'Helpdesk in depth report', 'Performance distribution', 'Ticket volume trend',
                          'Customer analysis', 'Ticket Lifecycle Report', 'Time sheet summary report', 'Satisfaction survey report', 'Shared ownership',
                          'Linked tracker ticket', 'Child parent ticket', 'Tags reports', 'Field service management report'].freeze

  # CURATED_REPORTS = {:agent_performance=>{:config_type=>:curated_reports, :value=>"Agent performance"}, :group_performance=>{:config_type=>:curated_reports, :value=>"Group performance"},...}
  CURATED_REPORTS = Hash[CURATED_REPORTS_LIST.map { |c| [c.tr('-', '_').parameterize('_').to_sym, { config_type: :curated_reports, value: c }] }]

  # List of Freshdesk resources that can be restricted at the account level in Fresh Visuals.
  RESOURCE_RESTRICTION_LIST = ['Tickets', 'Timesheet', 'Tags', 'CSAT questions', 'CSAT responses'].freeze

  # RESOURCE_RESTRICTION = {:tickets=>{:config_type=>:resource_restriction, :value=>"Tickets"}, :csat=>{:config_type=>:resource_restriction, :value=>"CSAT"}, :timesheet=>{:config_type=>:resource_restriction, :value=>"Timesheet"}, :tags=>{:config_type=>:resource_restriction, :value=>"Tags"}}
  RESOURCE_RESTRICTION = Hash[RESOURCE_RESTRICTION_LIST.map { |c| [c.parameterize('_').to_sym, { config_type: :resource_restriction, value: c }] }]

  # Map of Freshdesk features => Keys of Freshvisual features in this config file(FEATURE_CONFIGS, CURATED_REPORTS).
  # Values can be an array or an individual value also.
  FD_FRESVISUAL_FEATURE_MAPPING = {
    # Existing Reports features that have no mapping in freshvisuals.
    # enable_qna: [],
    # enable_insights: [],
    # new_ticket_recieved_metric: [],
    # year_in_review_2017: [],
    # year_in_review_2018: [],
    # ticket_activity_export: [],

    # Existing Reports features that have mapping in freshvisuals.
    timesheets: CURATED_REPORTS[:time_sheet_summary_report],
    advanced_reporting: CURATED_REPORTS[:helpdesk_in_depth_report],
    auto_ticket_export: FEATURE_CONFIGS[:landing_data_schedules],
    surveys: CURATED_REPORTS[:satisfaction_survey_report],
    enterprise_reporting: [CURATED_REPORTS[:ticket_volume_trend], CURATED_REPORTS[:performance_distribution], CURATED_REPORTS[:ticket_lifecycle_report], CURATED_REPORTS[:customer_analysis]],
    performance_report: [CURATED_REPORTS[:agent_performance], CURATED_REPORTS[:group_performance]],
    ticket_volume_report: CURATED_REPORTS[:ticket_volume_trend],

    # New features list.
    analytics_landing_search: FEATURE_CONFIGS[:landing_search],
    analytics_landing_data_schedules: FEATURE_CONFIGS[:landing_data_schedules],
    analytics_landing_new_report: FEATURE_CONFIGS[:landing_new_report],
    analytics_landing_navigation: FEATURE_CONFIGS[:landing_navigation],
    analytics_landing_nlp: FEATURE_CONFIGS[:landing_nlp],
    analytics_report_clone: FEATURE_CONFIGS[:report_clone],
    analytics_report_filter: FEATURE_CONFIGS[:report_filter],
    analytics_report_schedule: FEATURE_CONFIGS[:report_schedule],
    analytics_report_export: FEATURE_CONFIGS[:report_export],
    analytics_report_presentation_mode: FEATURE_CONFIGS[:report_presentation_mode],
    analytics_report_delete: FEATURE_CONFIGS[:report_delete],
    analytics_report_save: FEATURE_CONFIGS[:report_save],
    analytics_report_search_widget: FEATURE_CONFIGS[:report_search_widget],
    analytics_report_add_widgets: FEATURE_CONFIGS[:report_add_widgets],
    analytics_widget_schedule: FEATURE_CONFIGS[:widget_schedule],
    analytics_widget_export: FEATURE_CONFIGS[:widget_export],
    analytics_widget_save: FEATURE_CONFIGS[:widget_save],
    analytics_widget_save_as: FEATURE_CONFIGS[:widget_save_as],
    analytics_widget_add_to_reports: FEATURE_CONFIGS[:widget_add_to_reports],
    analytics_widget_change_chart: FEATURE_CONFIGS[:widget_change_chart],
    analytics_widget_filter: FEATURE_CONFIGS[:widget_filter],
    analytics_widget_show_tabular_data: FEATURE_CONFIGS[:widget_show_tabular_data],
    analytics_widget_edit_tabular_data: FEATURE_CONFIGS[:widget_edit_tabular_data],
    analytics_widget_delete: FEATURE_CONFIGS[:widget_delete],
    analytics_agent_performance: CURATED_REPORTS[:agent_performance],
    analytics_group_performance: CURATED_REPORTS[:group_performance],
    analytics_helpdesk_in_depth_report: CURATED_REPORTS[:helpdesk_in_depth_report],
    analytics_performance_distribution: CURATED_REPORTS[:performance_distribution],
    analytics_ticket_volume_trend: CURATED_REPORTS[:ticket_volume_trend],
    analytics_customer_analysis: CURATED_REPORTS[:customer_analysis],
    analytics_ticket_lifecycle_report: CURATED_REPORTS[:ticket_lifecycle_report],
    analytics_time_sheet_summary_report: CURATED_REPORTS[:time_sheet_summary_report],
    analytics_satisfaction_survey_report: CURATED_REPORTS[:satisfaction_survey_report],
    analytics_shared_ownership: CURATED_REPORTS[:shared_ownership],
    analytics_linked_tracker_ticket: CURATED_REPORTS[:linked_tracker_ticket],
    analytics_child_parent_ticket: CURATED_REPORTS[:child_parent_ticket],
    analytics_tags_reports: CURATED_REPORTS[:tags_reports],
    field_service_management: CURATED_REPORTS[:field_service_management_report],
    analytics_tickets_resource: RESOURCE_RESTRICTION[:tickets],
    analytics_timesheet_resource: RESOURCE_RESTRICTION[:timesheet],
    analytics_tags_resource: RESOURCE_RESTRICTION[:tags],
    analytics_csat_questions: RESOURCE_RESTRICTION[:csat_questions],
    analytics_csat_responses: RESOURCE_RESTRICTION[:csat_responses]
  }.freeze

  # Certain resources has to be enabled if some curated reports related to them is enabled. So, keeping a map like this.
  # {"Tickets"=>["Agent performance", "Group performance", "Helpdesk in depth report", "Performance distribution", "Ticket volume trend", "Customer analysis", "Ticket Lifecycle Report", "Shared ownership", "Linked tracker ticket", "Child parent ticket"], "CSAT"=>["Satisfaction survey report"], "Timesheet"=>["Time sheet summary report"], "Tags"=>["Tags reports"]}
  RESOURCE_CURATED_REPORTS_MAP = {
    RESOURCE_RESTRICTION[:tickets][:value] => [
      CURATED_REPORTS[:agent_performance][:value],
      CURATED_REPORTS[:group_performance][:value],
      CURATED_REPORTS[:helpdesk_in_depth_report][:value],
      CURATED_REPORTS[:performance_distribution][:value],
      CURATED_REPORTS[:ticket_volume_trend][:value],
      CURATED_REPORTS[:ticket_lifecycle_report][:value],
      CURATED_REPORTS[:shared_ownership][:value],
      CURATED_REPORTS[:linked_tracker_ticket][:value],
      CURATED_REPORTS[:child_parent_ticket][:value],
      CURATED_REPORTS[:field_service_management_report][:value]
    ],
    RESOURCE_RESTRICTION[:csat_questions][:value] => [CURATED_REPORTS[:satisfaction_survey_report][:value], CURATED_REPORTS[:customer_analysis][:value]],
    RESOURCE_RESTRICTION[:csat_responses][:value] => [CURATED_REPORTS[:satisfaction_survey_report][:value], CURATED_REPORTS[:customer_analysis][:value]],
    RESOURCE_RESTRICTION[:timesheet][:value] => [CURATED_REPORTS[:time_sheet_summary_report][:value]],
    RESOURCE_RESTRICTION[:tags][:value] => [CURATED_REPORTS[:tags_reports][:value]]
  }.freeze

  REPORTS_FEATURES_LIST = FD_FRESVISUAL_FEATURE_MAPPING.keys.freeze
end

# List of features
# FEATURE_CONFIGS
# analytics_landing_search
# analytics_landing_data_schedules
# analytics_landing_new_report
# analytics_landing_navigation
# analytics_landing_nlp
# analytics_report_clone
# analytics_report_filter
# analytics_report_schedule
# analytics_report_export
# analytics_report_presentation_mode
# analytics_report_delete
# analytics_report_save
# analytics_report_search_widget
# analytics_report_add_widgets
# analytics_widget_schedule
# analytics_widget_export
# analytics_widget_save
# analytics_widget_save_as
# analytics_widget_add_to_reports
# analytics_widget_change_chart
# analytics_widget_filter
# analytics_widget_show_tabular_data
# analytics_widget_edit_tabular_data
# analytics_widget_delete

# CURATED_REPORTS
# analytics_agent_performance
# analytics_group_performance
# analytics_helpdesk_in_depth_report
# analytics_performance_distribution
# analytics_ticket_volume_trend
# analytics_customer_analysis
# analytics_ticket_lifecycle_report
# analytics_time_sheet_summary_report
# analytics_satisfaction_survey_report
# analytics_shared_ownership
# analytics_linked_tracker_ticket
# analytics_child_parent_ticket
# analytics_tags_reports
# field_service_management

# RESOURCE_RESTRICTION_LIST
# analytics_tickets_resource
# analytics_timesheet_resource
# analytics_tags_resource
# analytics_csat_questions
# analytics_csat_responses
