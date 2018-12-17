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

    CUSTOM_FIELD_ALIASES = CUSTOM_FIELDS_TO_RESERVE.map { |field| field[:flexifield_alias] }
    DENORMOLIZED_CUSTOM_FIELDS_COUNT = { dropdown: 2, string: 3, date: 1 }.freeze
    NORMAL_CUSTOM_FIELDS_COUNT = { string: 5, date: 1 }.freeze

    FSM_DROPDOWN_OPTIONS = 24.times.map do |hour|
      time_interval = 30 #mins
      interval = (60/time_interval) # 2

      interval.times.map do |index|
        hours = hour < 10 ? "0#{hour}" : hour
        minutes = index == 0 ? "00" : index * time_interval
        {:value => "#{hours}:#{minutes}", 'position' => (hour * interval) + index + 1, '_destroy' => 0}
      end
    end.flatten.freeze

    FSM_FEATURE = :field_service_management
    SERVICE_TASK_TYPE = "Service Task"
    SERVICE_TASK_SECTION = "Service task section".freeze
    FIELD_AGENT = :field_agent
    SERVICE_TASK_MANDATORY_FIELDS = CUSTOM_FIELDS_TO_RESERVE.select { |field| field[:required] }.map { |field| field[:flexifield_alias] }
  end
end