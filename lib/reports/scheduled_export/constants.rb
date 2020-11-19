module Reports::ScheduledExport::Constants

  SCHEDULE_TYPE = {
    :SCHEDULED_TICKET_EXPORT => 1,
    :ACTIVITY_EXPORT => 2
  }

  SCHEDULE_TYPE_BY_VALUE = Hash[*SCHEDULE_TYPE.map { |i| [i[1], i[0]] }.flatten]

  DELIVERY_TYPES = {
    1 => :email,
    2 => :api
  }

  DELIVERY_FREQUENZY = [
    [:hourly,   0,  I18n.t('helpdesk_reports.ticket_schedule.new.schedule.hourly')],
    [:daily,    1,  I18n.t('helpdesk_reports.ticket_schedule.new.schedule.daily')],
    [:weekly,   2,  I18n.t('helpdesk_reports.ticket_schedule.new.schedule.weekly')]
  ]

  DELIVERY_DAYS = [
    ["Monday",    1,  I18n.t('helpdesk_reports.days.monday')],
    ["Tuesday",   2,  I18n.t('helpdesk_reports.days.tuesday')],
    ["Wednesday", 3,  I18n.t('helpdesk_reports.days.wednesday') ],
    ["Thursday",  4,  I18n.t('helpdesk_reports.days.thursday')],
    ["Friday",    5,  I18n.t('helpdesk_reports.days.friday')],
    ["Saturday",  6,  I18n.t('helpdesk_reports.days.saturday')],
    ["Sunday",    7,  I18n.t('helpdesk_reports.days.sunday')]
  ]

  DELIVERY_HOURS = [[0, "0:00"], [1, "1:00"], [2, "2:00"], [3, "3:00"],
    [4, "4:00"], [5, "5:00"], [6, "6:00"], [7, "7:00"], [8, "8:00"],
    [9, "9:00"], [10, "10:00"], [11, "11:00"], [12, "12:00"], [13, "13:00"],
    [14, "14:00"], [15, "15:00"], [16, "16:00"], [17, "17:00"], [18, "18:00"],
    [19, "19:00"], [20, "20:00"], [21, "21:00"], [22, "22:00"], [23, "23:00"]]

  DELIVERY_FREQUENZY_BY_KEYS  = Hash[*DELIVERY_FREQUENZY.map { |i| [i[0], i[1]] }.flatten]
  DELIVERY_FREQUENZY_BY_VALUE = Hash[*DELIVERY_FREQUENZY.map { |i| [i[1], i[0]] }.flatten]
  DELIVERY_DAYS_BY_KEYS       = Hash[*DELIVERY_DAYS.map { |i| [i[0], i[1]] }.flatten]
  DELIVERY_DAYS_BY_VALUE      = Hash[*DELIVERY_DAYS.map { |i| [i[1], i[0]] }.flatten]
  DELIVERY_TYPE_BY_VALUE      = Hash[*DELIVERY_TYPES.map { |i| [i[1], i[0]] }.flatten]

  EMAIL_RECIPIENTS_DELIMITTER = ","

  EXPORT_FIELD_TYPES = ["ticket", "contact", "company"]

  NEGLECT_TYPES = [:requester, :company]

  NONE_VALUE = '-1'

  DEFAULT_ATTRIBUTES = {
  	:name => I18n.t(:'helpdesk_reports.ticket_activity.default.field_value.name'),
  	:description => I18n.t(:'helpdesk_reports.ticket_activity.default.field_value.description'),
  	:active => false
  }

  ACTIVITY_EXPORT_API = "https://%{domain}.freshdesk.com/api/v2/export/ticket_activities" 

  PROPERTY_EXPORT_ACTIONS = [:new, :create, :show, :destroy, :download_file, :clone_schedule].freeze
  ACTIVITY_EXPORT_ACTIONS = [:edit_activity, :update_activity].freeze
end
