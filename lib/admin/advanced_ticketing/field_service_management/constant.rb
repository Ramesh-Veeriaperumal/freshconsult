module Admin::AdvancedTicketing::FieldServiceManagement
  module Constant
    include ::Dashboard::Custom::CustomDashboardConstants
    include ApiTicketConstants

    CUSTOM_FIELDS_TO_RESERVE = [
      {
        label: 'Contact',
        type: 'text',
        field_type: 'custom_text',
        label_in_portal: 'Contact',
        name: 'cf_fsm_contact_name',
        required: true,
        flexifield_alias: 'fsm_contact_name'
      },
      {
        label: 'Phone number',
        type: 'text',
        field_type: 'custom_text',
        label_in_portal: 'Customer phone number',
        name: 'cf_fsm_phone_number',
        required: true,
        flexifield_alias: 'fsm_phone_number'
      },
      {
        label: 'Service location',
        type: 'text',
        field_type: 'custom_text',
        label_in_portal: 'Service location',
        name: 'cf_fsm_service_location',
        required: true,
        flexifield_alias: 'fsm_service_location'
      },
      {
        label: 'Appointment start time',
        type: 'date_time',
        field_type: 'custom_date_time',
        label_in_portal: 'Appointment start time',
        name: 'cf_fsm_appointment_start_time',
        flexifield_alias: 'fsm_appointment_start_time'
      },
      {
        label: 'Appointment end time',
        type: 'date_time',
        field_type: 'custom_date_time',
        label_in_portal: 'Appointment end time',
        name: 'cf_fsm_appointment_end_time',
        flexifield_alias: 'fsm_appointment_end_time'
      }
    ].freeze

    DENORMOLIZED_CUSTOM_FIELDS_COUNT = { string: 3, date_time: 2 }.freeze
    NORMAL_CUSTOM_FIELDS_COUNT = { string: 3, date_time: 2 }.freeze
    FSM_FEATURE = :field_service_management
    SERVICE_TASK_TYPE = 'Service Task'
    FIELD_AGENT = :field_agent
    FSM_FIELDS_PREFIX = 'cf_fsm_'.freeze
    SUPPORT_AGENT_TYPE = 1
    SUPPORT_GROUP_TYPE = 1
    SERVICE_TASK_SECTION = 'Service task section'.freeze

    SCORE_CARD = 'scorecard'.freeze

    TICKET_TREND_CARD = 'ticket_trend_card'.freeze

    TIME_TREND_CARD = 'time_trend_card'.freeze

    SERVICE_TASKS_INCOMING_TREND_WIDGET_NAME = 'incoming_service_tasks_trend'.freeze
    SERVICE_TASKS_RESOLUTION_TREND_WIDGET_NAME = 'service_tasks_resolution_trend'.freeze
    SERVICE_TASKS_AVG_RESOLUTION_WIDGET_NAME = 'service_tasks_avg_resolution'.freeze
    SERVICE_TASKS_DUE_TODAY_WIDGET_NAME = 'service_tasks_due_today'.freeze
    SERVICE_TASKS_UNASSIGNED_WIDGET_NAME = 'unassigned_service_tasks'.freeze
    SERVICE_TASKS_OVERDUE_WIDGET_NAME = 'overdue_service_tasks'.freeze

    WIDGETS_NAME_TO_TYPE_MAP = {
      SERVICE_TASKS_INCOMING_TREND_WIDGET_NAME => WIDGET_MODULE_TOKEN_BY_NAME[TICKET_TREND_CARD],
      SERVICE_TASKS_RESOLUTION_TREND_WIDGET_NAME => WIDGET_MODULE_TOKEN_BY_NAME[TICKET_TREND_CARD],
      SERVICE_TASKS_AVG_RESOLUTION_WIDGET_NAME => WIDGET_MODULE_TOKEN_BY_NAME[TIME_TREND_CARD],
      SERVICE_TASKS_DUE_TODAY_WIDGET_NAME => WIDGET_MODULE_TOKEN_BY_NAME[SCORE_CARD],
      SERVICE_TASKS_UNASSIGNED_WIDGET_NAME => WIDGET_MODULE_TOKEN_BY_NAME[SCORE_CARD],
      SERVICE_TASKS_OVERDUE_WIDGET_NAME => WIDGET_MODULE_TOKEN_BY_NAME[SCORE_CARD]
    }.freeze

    FSM_TICKET_FILTERS = ["service_tasks_due_today", "unassigned_service_tasks", "overdue_service_tasks"].freeze

    FSM_WIDGETS_COUNT = WIDGETS_NAME_TO_TYPE_MAP.size

    FSM_TICKET_FILTER_COUNT = FSM_TICKET_FILTERS.size

    COMMON_FILTER_CONDITIONS = [
      { 'condition' => 'status', 'operator' => 'is_in', 'value' => "#{OPEN},#{PENDING}", 'ff_name' => 'default' },
      { 'condition' => 'spam', 'operator' => 'is', 'value' => false },
      { 'condition' => 'deleted', 'operator' => 'is', 'value' => false },
      { 'condition' => 'ticket_type', 'operator' => 'is_in', 'value' => SERVICE_TASK_TYPE, 'ff_name' => 'default' }
   ].freeze

    Y_AXIS_POSITION = { trend: 0, scorecard: 1 }.freeze

    TRENDS_WIDGET_TO_METRIC_MAP = {
      SERVICE_TASKS_INCOMING_TREND_WIDGET_NAME => ::Dashboard::Custom::TicketTrendCard::METRICS_MAPPING.key('RECEIVED_TICKETS'),
      SERVICE_TASKS_RESOLUTION_TREND_WIDGET_NAME => ::Dashboard::Custom::TicketTrendCard::METRICS_MAPPING.key('RESOLVED_TICKETS'),
      SERVICE_TASKS_AVG_RESOLUTION_WIDGET_NAME => ::Dashboard::Custom::TimeTrendCard::METRICS_MAPPING.key('AVG_RESOLUTION_TIME')
    }.freeze
  end
end
