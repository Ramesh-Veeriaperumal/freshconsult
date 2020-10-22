module Admin::AdvancedTicketing::FieldServiceManagement
  module Constant
    include ::Dashboard::Custom::CustomDashboardConstants
    include ApiTicketConstants

    CUSTOMER_SIGNATURE = 'cf_fsm_customer_signature'.freeze
    FSM_DEFAULT_TICKET_FIELDS = [
      {
        label: I18n.t('ticket_fields.field_service_fields.cf_fsm_contact_name'),
        type: 'text',
        field_type: 'custom_text',
        label_in_portal: 'Contact',
        name: 'cf_fsm_contact_name',
        required: true,
        flexifield_alias: 'fsm_contact_name'
      },
      {
        label: I18n.t('ticket_fields.field_service_fields.cf_fsm_phone_number'),
        type: 'text',
        field_type: 'custom_text',
        label_in_portal: 'Customer phone number',
        name: 'cf_fsm_phone_number',
        required: true,
        flexifield_alias: 'fsm_phone_number'
      },
      {
        label: I18n.t('ticket_fields.field_service_fields.cf_fsm_service_location'),
        type: 'text',
        field_type: 'custom_text',
        label_in_portal: 'Service location',
        name: 'cf_fsm_service_location',
        required: true,
        flexifield_alias: 'fsm_service_location'
      },
      {
        label: I18n.t('ticket_fields.field_service_fields.cf_fsm_appointment_start_time'),
        type: 'date_time',
        field_type: 'custom_date_time',
        label_in_portal: 'Appointment start time',
        name: 'cf_fsm_appointment_start_time',
        flexifield_alias: 'fsm_appointment_start_time'
      },
      {
        label: I18n.t('ticket_fields.field_service_fields.cf_fsm_appointment_end_time'),
        type: 'date_time',
        field_type: 'custom_date_time',
        label_in_portal: 'Appointment end time',
        name: 'cf_fsm_appointment_end_time',
        flexifield_alias: 'fsm_appointment_end_time'
      },
      {
        label: I18n.t('ticket_fields.field_service_fields.cf_fsm_customer_signature'),
        type: 'file',
        field_type: 'custom_file',
        label_in_portal: "Customer's signature",
        name: CUSTOMER_SIGNATURE,
        required: false,
        flexifield_alias: 'fsm_customer_signature'
      }
    ].freeze

    FSM_FEATURE = :field_service_management
    SERVICE_TASK_TYPE = 'Service Task'
    FIELD_AGENT = :field_agent
    FSM_FIELDS_PREFIX = 'cf_fsm_'.freeze
    SUPPORT_AGENT_TYPE = 1
    SUPPORT_GROUP_TYPE = 1

    FSM_APPOINTMENT_START_TIME = 'cf_fsm_appointment_start_time'.freeze
    FSM_APPOINTMENT_END_TIME = 'cf_fsm_appointment_end_time'.freeze
    SERVICE_TASK_SECTION = 'Service task section'.freeze
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
