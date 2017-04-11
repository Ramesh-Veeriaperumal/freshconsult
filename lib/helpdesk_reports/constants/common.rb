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
    :satisfaction_survey           => 1010 }.freeze

  DEFAULT_REPORTS     = [ :agent_summary, :group_summary ]
  ADVANCED_REPORTS    = DEFAULT_REPORTS + [ :glance ]
  ENTERPRISE_REPORTS  = ADVANCED_REPORTS + [ :ticket_volume, :performance_distribution, :customer_report ] 

  REPORT_ENUM_TO_TYPE  = REPORT_TYPE_TO_ENUM.invert.freeze

  LIST_REPORT_TYPES = REPORT_TYPE_TO_ENUM.keys.freeze

end