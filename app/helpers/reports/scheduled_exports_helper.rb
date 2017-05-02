module Reports::ScheduledExportsHelper
  include Reports::ScheduledExport::Constants

  def index_scheduled_message(frequency, day_of_export, minute_of_day)
    message = case frequency.to_i
    when DELIVERY_FREQUENZY_BY_KEYS[:hourly]
      t('helpdesk_reports.ticket_schedule.index.scheduled_hourly')
    when DELIVERY_FREQUENZY_BY_KEYS[:daily]
      t('helpdesk_reports.ticket_schedule.index.scheduled_daily',:hrs =>minute_of_day)
    when DELIVERY_FREQUENZY_BY_KEYS[:weekly]
      t('helpdesk_reports.ticket_schedule.index.scheduled_weekly', :day => DELIVERY_DAYS_BY_VALUE[day_of_export.to_i], :hrs =>minute_of_day)
    else
      ""
    end
  end

  def get_search_data_with_email_ids user_ids
    current_account.technicians.where(:id => user_ids).map(&:search_data).flatten
  end

  def check_for_auto_ticket_export_feature?
    Account.current.auto_ticket_export_enabled? and privilege?(:admin_tasks)
  end

  def user_timezone user
    ActiveSupport::TimeZone.new(user.time_zone).now.zone
  end
end
