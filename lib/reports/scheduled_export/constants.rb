module Reports::ScheduledExport::Constants

  SCHEDULE_TYPE = {
    :TICKET_SCHEDULED_EXPORT => 1,
    :ACTIVITY_EXPORT => 2
  }

  SCHEDULE_TYPE_BY_VALUE = Hash[*SCHEDULE_TYPE.map { |i| [i[1], i[0]] }.flatten]

  DEFAULT_ATTRIBUTES = {
  	:name => I18n.t(:'helpdesk_reports.ticket_activity.default.field_value.name'),
  	:description => I18n.t(:'helpdesk_reports.ticket_activity.default.field_value.description'),
  	:active => false
  }

  ACTIVITY_EXPORT_API = "https://%{domain}.freshdesk.com/api/v2/export/ticket_activities" 

end
