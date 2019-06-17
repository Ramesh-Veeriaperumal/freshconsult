module TicketFilterConstants
  # ControllerConstants

  HIDDEN_FILTERS = %w[overdue due_today on_hold new open article_feedback my_article_feedback unresolved_article_feedback].freeze

  FILTER = (Helpdesk::Filters::CustomTicketFilter::DEFAULT_FILTERS.keys |
      %w[watching on_hold raised_by_me shared_by_me shared_with_me unresolved_service_tasks]).freeze

  INDEX_FIELDS = %w[filter ids company_id requester_id email order_by order_type updated_since include query_hash only article_id exclude portal_id language_id].freeze

  RENAME_FILTER_NAMES = { 'watching' => 'monitored_by' }.freeze

  SIDE_LOADING_FEATURES = [
    ['survey', :new_survey, 'Custom survey']
  ].freeze

  FEATURES_KEYS_BY_SIDE_LOAD_KEY   = Hash[*SIDE_LOADING_FEATURES.map { |i| [i[0], i[1]] }.flatten]
  FEATURES_NAMES_BY_SIDE_LOAD_KEY  = Hash[*SIDE_LOADING_FEATURES.map { |i| [i[0], i[2]] }.flatten]

  VISIBILITY_ATTRIBUTES_NEEDED = %w(visibility group_id user_id).freeze

  WRAP_PARAMS = [:ticket_filter, exclude: [], format: [:json]].freeze

  FSM_APPOINTMENT_START_TIME = 'cf_fsm_appointment_start_time'.freeze

  FSM_APPOINTMENT_END_TIME = 'cf_fsm_appointment_end_time'.freeze

  FSM_DATE_TIME_FIELDS = [FSM_APPOINTMENT_START_TIME, FSM_APPOINTMENT_END_TIME].freeze

  DATE_TIME_FILTER_DEFAULT_OPTIONS = ['today', 'tomorrow', 'yesterday', 'week', 'last_week', 'next_week', 'in_the_past'].freeze

  DATE_TIME_FILTER_DEFAULT_OPTIONS_HASH = Hash[DATE_TIME_FILTER_DEFAULT_OPTIONS.map { |option| [option.to_sym, option] }]

  DATE_FIELD_REGEX = /^[0-9]{4}\-[0-1][0-9]\-[0-3][0-9]$/i

  SORTABLE_CUSTOM_FIELDS = { 'appointment_start_time' => FSM_APPOINTMENT_START_TIME }.freeze

  ES_SUPPORTED_FILTERS = ['unresolved_service_tasks'].freeze
end.freeze
