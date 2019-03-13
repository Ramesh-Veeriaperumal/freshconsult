module Admin::AdvancedTicketing::FieldServiceManagement
  module Constant
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
        label: 'Phone Number',
        type: 'text',
        field_type: 'custom_text',
        label_in_portal: 'Customer Phone Number',
        name: 'cf_fsm_phone_number',
        required: true,
        flexifield_alias: 'fsm_phone_number'
      },
      {
        label: 'Service Location',
        type: 'text',
        field_type: 'custom_text',
        label_in_portal: 'Service Location',
        name: 'cf_fsm_service_location',
        required: true,
        flexifield_alias: 'fsm_service_location'
      },
      {
        label: 'Appointment Start Time',
        type: 'date_time',
        field_type: 'custom_date_time',
        label_in_portal: 'Appointment Start Time',
        name: 'cf_fsm_appointment_start_time',
        flexifield_alias: 'fsm_appointment_start_time'
      },
      {
        label: 'Appointment End Time',
        type: 'date_time',
        field_type: 'custom_date_time',
        label_in_portal: 'Appointment End Time',
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
  end
end
