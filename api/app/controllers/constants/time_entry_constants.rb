module TimeEntryConstants
  # ControllerConstants
  INDEX_FIELDS = %w(company_id agent_id executed_after executed_before billable).freeze
  CREATE_FIELDS = { all: %w(billable executed_at note time_spent timer_running start_time), edit_time_entries: %w(agent_id) }.freeze
  UPDATE_FIELDS = { all: %w(billable agent_id executed_at note time_spent start_time timer_running) }.freeze # privilege for update is edit_time_entries.
  LOAD_OBJECT_EXCEPT = [:ticket_time_entries].freeze

  FIELDS_TO_BE_STRIPPED = %w(note time_spent).freeze
end.freeze
