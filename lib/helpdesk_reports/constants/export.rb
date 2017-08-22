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
        "created_at",
        "resolved_at",
        "closed_at",
        "updated_at",
        "time_tracked_hours",
        "outbound_count",
        "inbound_count",
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
        "due_by",
        "first_response_time",
        "first_res_time_bhrs",
        "resolution_time_bhrs",
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
        :phone_summary            => "Phone Summary",
        :satisfaction_survey      => "Satisfaction Survey",
        :timespent                => "Ticket Lifecycle"
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

      CSV_EXPORT_TYPE = "report_export/csv"

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
          received_resolved_tickets: :trend,
          unresolved_previous_benchmark: :trend,
          received_resolved_benchmark: :trend,
          unresolved_current_benchmark: :trend
        }
      }

      SURVEY_EXPORT_FIELDS = [
        [ :created_at                                                         ],
        [ :surveyable,                       :display_id                      ],
        [ :rating_text_for_custom_questions, 0,             :cf_int01         ],
        [ :rating_text_for_custom_questions, 1,             :cf_int02         ],
        [ :rating_text_for_custom_questions, 2,             :cf_int03         ],
        [ :rating_text_for_custom_questions, 3,             :cf_int04         ],
        [ :rating_text_for_custom_questions, 4,             :cf_int05         ],
        [ :rating_text_for_custom_questions, 5,             :cf_int06         ],
        [ :rating_text_for_custom_questions, 6,             :cf_int07         ],
        [ :rating_text_for_custom_questions, 7,             :cf_int08         ],
        [ :rating_text_for_custom_questions, 8,             :cf_int09         ],
        [ :rating_text_for_custom_questions, 9,             :cf_int10         ],
        [ :rating_text_for_custom_questions, 10,            :cf_int11         ],
        [ :survey_remark,                    :feedback,     :body,    :squish ],
        [ :surveyable,                       :requester,    :name             ],
        [ :surveyable,                       :requester,    :email            ],
        [ :surveyable,                       :company,      :name             ],
        [ :surveyable,                       :group,        :name             ],
        [ :agent,                            :name                            ],
      ]

      SURVEY_CSV_HEADERS_1 = [ I18n.t("export_data.fields.survey_received"), 
                               I18n.t("export_data.fields.ticket_id"), 
                               I18n.t("export_data.fields.rating") ] 

      SURVEY_CSV_HEADERS_2 = [ I18n.t("export_data.fields.comment"), 
                               I18n.t("export_data.fields.requester_name"), 
                               I18n.t("export_data.fields.requester_email"),
                               I18n.t("export_data.fields.company"), 
                               I18n.t("export_data.fields.group"), 
                               I18n.t("export_data.fields.agent") ]

      AGENT_ALL_URL_REF = 'a'
      GROUP_ALL_URL_REF = 'g'
      RATING_ALL_URL_REF = 'r'


    end
  end
end      
