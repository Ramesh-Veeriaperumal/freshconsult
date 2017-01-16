module TimeEntryConstants
  # ControllerConstants
  INDEX_FIELDS = %w(company_id agent_id executed_after executed_before billable).freeze
  FIELDS = { all: %w(billable executed_at note time_spent timer_running start_time), edit_time_entries: %w(agent_id) }.freeze
  LOAD_OBJECT_EXCEPT = [:ticket_time_entries].freeze

  ATTRIBUTES_TO_BE_STRIPPED = %w(note time_spent).freeze
  NO_CONTENT_TYPE_REQUIRED = [:toggle_timer].freeze
end.freeze
