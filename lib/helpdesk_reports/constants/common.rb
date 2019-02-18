module HelpdeskReports::Constants::Common

  REPORT_TYPE_TO_ENUM = {
    :glance                        => 1001,
    :ticket_volume                 => 1002,
    :performance_distribution      => 1003,
    :agent_summary                 => 1004,
    :group_summary                 => 1005,
    :customer_report               => 1006,
    :chat_summary                  => 1007,
    :phone_summary                 => 1008,
    :timesheet_reports             => 1009,
    :satisfaction_survey           => 1010,
    :timespent                     => 1011,
    :qna                           => 1012,
    :insights                      => 1013,
    :threshold                     => 1014}.freeze

  DEFAULT_REPORTS     = [ :ticket_volume, :agent_summary, :group_summary, :threshold ]
  ADVANCED_REPORTS    = DEFAULT_REPORTS + [ :glance  ]
  ENTERPRISE_REPORTS  = ADVANCED_REPORTS + [ :performance_distribution, :customer_report, :timespent, :qna, :insights]

  REPORT_ENUM_TO_TYPE  = REPORT_TYPE_TO_ENUM.invert.freeze

  LIST_REPORT_TYPES = REPORT_TYPE_TO_ENUM.keys.freeze

end