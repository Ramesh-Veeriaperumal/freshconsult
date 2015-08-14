module TimeSheetConstants
  # ControllerConstants
  INDEX_FIELDS = %w(company_id user_id executed_after executed_before billable)
  CREATE_FIELDS = { all: %w(billable ticket_id executed_at note time_spent timer_running start_time), edit_time_entries: %w(user_id) }
  UPDATE_FIELDS = { all: %w(billable user_id executed_at note time_spent start_time timer_running) }
  LOAD_OBJECT_EXCEPT = [:ticket_time_sheets]
end
