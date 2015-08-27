module TimeSheetConstants
  # ControllerConstants
  INDEX_FIELDS = %w(company_id agent_id executed_after executed_before billable)
  CREATE_FIELDS = { all: %w(billable ticket_id executed_at note time_spent timer_running start_time), edit_time_entries: %w(agent_id) }
  UPDATE_FIELDS = { all: %w(billable agent_id executed_at note time_spent start_time timer_running) }
  LOAD_OBJECT_EXCEPT = [:ticket_time_sheets]

  FIELDS_TO_BE_STRIPPED = %w(note time_spent billable timer_running)
end
