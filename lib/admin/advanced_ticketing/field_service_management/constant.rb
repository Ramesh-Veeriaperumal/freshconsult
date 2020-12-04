module Admin::AdvancedTicketing::FieldServiceManagement
  module Constant
    include ::Dashboard::Custom::CustomDashboardConstants
    include ApiTicketConstants

    CUSTOMER_SIGNATURE = 'cf_fsm_customer_signature'.freeze
    FSM_DEFAULT_TICKET_FIELDS = [
      {
        label: 'Appointment time',
        type: 'date_time',
        field_type: 'custom_date_time',
        label_in_portal: 'Appointment time',
        name: 'cf_fsm_appointment_start_time',
        flexifield_alias: 'fsm_appointment_start_time'
      },
      {
        label: 'Add Payment',
        type: 'checkbox',
        field_type: 'custom_checkbox',
        label_in_portal: 'Add Payment',
        name: 'cf_fsm_payment_details',
        flexifield_alias: 'fsm_payment_details'
      }
    ].freeze

    CONSULTATION_DROPDOWN_FIELDS = [
      {
        label: 'Appointment Duration',
        type: 'dropdown',
        field_type: 'custom_dropdown',
        label_in_portal: 'Appointment Duration',
        name: 'cf_appointment_duration',
        flexifield_alias: 'appointment_duration',
        choices: ['15 minutes', '30 minutes', '45 minutes', '1 hour', '1 hour 15 minutes', '1 hour 30 minutes', '2 hours']
      }
    ].freeze

    CUSTOMER_SELECT_FIELDS = [
      {
        label: 'Your Name',
        type: 'text',
        field_type: 'custom_text',
        label_in_portal: 'Your Name',
        name: 'cf_your_contact_name',
        required: true,
        visible_in_portal: true,
        flexifield_alias: 'your_contact_name'
      },
      {
        label: 'Your contact details (Mobile Number)',
        type: 'text',
        field_type: 'custom_text',
        label_in_portal: 'Your contact details (Mobile Number)',
        name: 'cf_your_phone_number',
        visible_in_portal: true,
        flexifield_alias: 'your_phone_number'
      },
      {
        label: 'Preffered Communication Type',
        type: 'dropdown',
        field_type: 'custom_dropdown',
        label_in_portal: 'Preffered Communication Type',
        name: 'cf_preffered_communication_type',
        visible_in_portal: true,
        flexifield_alias: 'preffered_communication_type',
        choices: ['Voice Call', 'Video Call']
      },
      {
        label: 'Preffered Appointment Duration',
        type: 'dropdown',
        field_type: 'custom_dropdown',
        label_in_portal: 'Preffered Appointment Duration',
        name: 'cf_preffered_appointment_duration',
        flexifield_alias: 'preffered_appointment_duration',
        visible_in_portal: true,
        choices: ['15 minutes', '30 minutes', '45 minutes', '1 hour', '1 hour 15 minutes', '1 hour 30 minutes', '2 hours']
      }
    ].freeze

    TIME_TO_SECONDS_MAPPING = {
      '15 minutes': 900,
      '30 minutes': 1800,
      '45 minutes': 2700,
      '1 hour': 3600,
      '1 hour 15 minutes': 4500,
      '1 hour 30 minutes': 5400,
      '2 hours': 7200
    }.freeze

    CONSULT_AUTOMATION_RULE = {
      name: 'Consultation Ticket Creation Rule',
      description: 'Consultation Ticket Creation Rule',
      active: 1,
      rule_type: 1,
      action_data: [{ name: 'ticket_type', value: 'Consultation' }],
      condition_data: {
        all: [
          {
            evaluate_on: :ticket,
            name: "cf_preffered_communication_type_1",
            operator: "in", value: ["Video Call", "Voice Call"]
          },
          {
            evaluate_on: :ticket,
            name: "cf_preffered_appointment_duration_1",
            operator: "in", value: ["15 minutes", "30 minutes", "45 minutes", "1 hour", "1 hour 15 minutes", "1 hour 30 minutes", "2 hours"]
          }
        ]
      }
    }.freeze

    FSM_FEATURE = :field_service_management
    SERVICE_TASK_TYPE = 'Service Task'
    CONSULTATION_TASK = 'Consultation'
    FIELD_AGENT = :field_agent
    FSM_FIELDS_PREFIX = 'cf_fsm_'.freeze
    SUPPORT_AGENT_TYPE = 1
    SUPPORT_GROUP_TYPE = 1

    FSM_APPOINTMENT_START_TIME = 'cf_fsm_appointment_start_time'.freeze
    FSM_APPOINTMENT_END_TIME = 'cf_fsm_appointment_end_time'.freeze
    SERVICE_TASK_SECTION = 'Service task section'.freeze
    CONSULTATION_SECTION = 'Consultation'.freeze
    FIELD_SERVICE_MANAGER_ROLE_NAME = 'Field service manager'.freeze
    FIELD_SERVICE_MANAGER_ROLE_PRIVILEGES = Helpdesk::Roles::AGENT + [:schedule_fsm_dashboard, :access_to_map_view]

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

    FIELD_SERVICE_PARAMS_SETTINGS_MAPPING = {
      geo_location_enabled: :field_service_geolocation,
      location_tagging_enabled: :location_tagging
    }.freeze

    SETTINGS_LAUNCH_PARTY_MAPPING = {
      field_service_geolocation: :launch_fsm_geolocation
    }.freeze

    FSM_TICKET_FILTERS = ['service_tasks_due_today', 'unassigned_service_tasks', 'overdue_service_tasks', 'unresolved_service_tasks', 'service_tasks_starting_today'].freeze
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

    FSM_ADDITIONAL_SETTINGS_DEFAULT_VALUES = { field_agents_can_manage_appointments: true }.freeze
    UPDATE_SETTINGS_FIELDS = (FSM_ADDITIONAL_SETTINGS_DEFAULT_VALUES.keys | [:geo_location_enabled, :location_tagging_enabled]).freeze

    FSM_SETTINGS_TO_RETAIN_STATE = [:location_tagging].freeze
  end
end
