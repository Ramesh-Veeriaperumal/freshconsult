module TimeSheetConstants
  # *********************************-- ControllerConstants --*********************************************
  INDEX_TIMESHEET_FIELDS = %w(company_id user_id executed_after executed_before billable group_id pp)
  CREATE_TIME_SHEET_FIELDS = %w(billable ticket_id executed_at note time_spent timer_running start_time user_id)
  UPDATE_TIME_SHEET_FIELDS = {all: %w(billable user_id executed_at note time_spent) }

end
