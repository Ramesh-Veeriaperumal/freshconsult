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
        label: 'Appointment Date',
        type: 'date',
        field_type: 'custom_date',
        label_in_portal: 'Appointment Date',
        name: 'cf_fsm_appointment_date',
        flexifield_alias: 'fsm_appointment_date'
      },
      {
        label: 'Appointment Start Time',
        type: 'dropdown',
        field_type: 'custom_dropdown',
        label_in_portal: 'Appointment start time',
        name: 'cf_fsm_appointment_start_time',
        flexifield_alias: 'fsm_appointment_start_time'
      },
      {
        label: 'Appointment End Time',
        type: 'dropdown',
        field_type: 'custom_dropdown',
        label_in_portal: 'Appointment end time',
        name: 'cf_fsm_appointment_end_time',
        flexifield_alias: 'fsm_appointment_end_time'
      }
    ].freeze

    DENORMOLIZED_CUSTOM_FIELDS_COUNT = { dropdown: 2, string: 3, date: 1 }.freeze
    NORMAL_CUSTOM_FIELDS_COUNT = { string: 5, date: 1 }.freeze
    FSM_DROPDOWN_OPTIONS = [{ :value => '00:00', 'position' => 1, '_destroy' => 0 }, { :value => '00:30', 'position' => 2, '_destroy' => 0 }, { :value => '01:00', 'position' => 3, '_destroy' => 0 }, { :value => '01:30', 'position' => 4, '_destroy' => 0 }, { :value => '02:00', 'position' => 5, '_destroy' => 0 }, { :value => '02:30', 'position' => 6, '_destroy' => 0 }, { :value => '03:00', 'position' => 7, '_destroy' => 0 }, { :value => '03:30', 'position' => 8, '_destroy' => 0 }, { :value => '04:00', 'position' => 9, '_destroy' => 0 }, { :value => '04:30', 'position' => 10, '_destroy' => 0 }, { :value => '05:00', 'position' => 11, '_destroy' => 0 }, { :value => '05:30', 'position' => 12, '_destroy' => 0 }, { :value => '06:00', 'position' => 13, '_destroy' => 0 }, { :value => '06:30', 'position' => 14, '_destroy' => 0 }, { :value => '07:00', 'position' => 15, '_destroy' => 0 }, { :value => '07:30', 'position' => 16, '_destroy' => 0 }, { :value => '08:00', 'position' => 17, '_destroy' => 0 }, { :value => '08:30', 'position' => 18, '_destroy' => 0 }, { :value => '09:00', 'position' => 19, '_destroy' => 0 }, { :value => '09:30', 'position' => 20, '_destroy' => 0 }, { :value => '10:00', 'position' => 21, '_destroy' => 0 }, { :value => '10:30', 'position' => 22, '_destroy' => 0 }, { :value => '11:00', 'position' => 23, '_destroy' => 0 }, { :value => '11:30', 'position' => 24, '_destroy' => 0 }, { :value => '12:00', 'position' => 25, '_destroy' => 0 }, { :value => '12:30', 'position' => 26, '_destroy' => 0 }, { :value => '13:00', 'position' => 27, '_destroy' => 0 }, { :value => '13:30', 'position' => 28, '_destroy' => 0 }, { :value => '14:00', 'position' => 29, '_destroy' => 0 }, { :value => '14:30', 'position' => 30, '_destroy' => 0 }, { :value => '15:00', 'position' => 31, '_destroy' => 0 }, { :value => '15:30', 'position' => 32, '_destroy' => 0 }, { :value => '16:00', 'position' => 33, '_destroy' => 0 }, { :value => '16:30', 'position' => 34, '_destroy' => 0 }, { :value => '17:00', 'position' => 35, '_destroy' => 0 }, { :value => '17:30', 'position' => 36, '_destroy' => 0 }, { :value => '18:00', 'position' => 37, '_destroy' => 0 }, { :value => '18:30', 'position' => 38, '_destroy' => 0 }, { :value => '19:00', 'position' => 39, '_destroy' => 0 }, { :value => '19:30', 'position' => 40, '_destroy' => 0 }, { :value => '20:00', 'position' => 41, '_destroy' => 0 }, { :value => '20:30', 'position' => 42, '_destroy' => 0 }, { :value => '21:00', 'position' => 43, '_destroy' => 0 }, { :value => '21:30', 'position' => 44, '_destroy' => 0 }, { :value => '22:00', 'position' => 45, '_destroy' => 0 }, { :value => '22:30', 'position' => 46, '_destroy' => 0 }, { :value => '23:00', 'position' => 47, '_destroy' => 0 }, { :value => '23:30', 'position' => 48, '_destroy' => 0 }].freeze
    FSM_FEATURE = :field_service_management
    SERVICE_TASK_TYPE = "Service Task"
    FIELD_AGENT = :field_agent
    SERVICE_TASK_MANDATORY_FIELDS = CUSTOM_FIELDS_TO_RESERVE.select { |field| field[:required] }.map { |field| field[:flexifield_alias] }
    FSM_FIELDS_PREFIX = 'cf_fsm_'.freeze
    SUPPORT_AGENT_TYPE = 1
    SUPPORT_GROUP_TYPE = 1
  end
end
