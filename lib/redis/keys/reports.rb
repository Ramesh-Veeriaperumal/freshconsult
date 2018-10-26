module Redis::Keys::Reports
  REPORT_STATS_REGENERATE_KEY     = "REPORT_STATS_REGENERATE:%{account_id}".freeze # set of dates for which stats regeneration will happen
  REPORT_STATS_EXPORT_HASH        = "REPORT_STATS_EXPORT_HASH:%{account_id}".freeze # last export date, last archive job id and last regen job id
  ENTERPRISE_REPORTS_ENABLED      = "ENTERPRISE_REPORTS_ENABLED".freeze
  BI_REPORTS_INTERNAL_CSV_EXPORT  = "BI_REPORTS_INTERNAL_CSV_EXPORT".freeze
  BI_REPORTS_MAIL_ATTACHMENT_LIMIT_IN_BYTES = "BI_REPORTS_MAIL_ATTACHMENT_LIMIT_IN_BYTES".freeze
end