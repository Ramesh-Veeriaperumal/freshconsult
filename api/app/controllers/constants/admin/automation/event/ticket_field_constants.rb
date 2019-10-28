module Admin::Automation::Event::TicketFieldConstants
  EVENT_FIELDS_HASH = [
    { name: :priority, field_type: :dropdown, expect_from_to: true, data_type: :Integer,
      invalid_rule_types: [1, 3] }.freeze,
    { name: :ticket_type, field_type: :dropdown, expect_from_to: true, data_type: :String,
      invalid_rule_types: [1, 3] }.freeze,
    { name: :status, field_type: :dropdown, expect_from_to: true, data_type: :Integer,
      invalid_rule_types: [1, 3] }.freeze,
    { name: :group_id, field_type: :dropdown, expect_from_to: true, data_type: :Integer,
      invalid_rule_types: [1, 3] }.freeze,
    { name: :responder_id, field_type: :dropdown, expect_from_to: true,
      invalid_rule_types: [1, 3] }.freeze,
    { name: :note_type, field_type: :dropdown, expect_from_to: false, data_type: :String,
      invalid_rule_types: [1, 3] }.freeze,
    { name: :reply_sent, field_type: :label, expect_from_to: false,
      invalid_rule_types: [1, 3] }.freeze,
    { name: :due_by, field_type: :label, expect_from_to: false,
      invalid_rule_types: [1, 3] }.freeze,
    { name: :ticket_action, field_type: :dropdown, expect_from_to: false, data_type: :String,
      invalid_rule_types: [1, 3] }.freeze,
    { name: :time_sheet_action, field_type: :dropdown, expect_from_to: false, data_type: :String,
      invalid_rule_types: [1, 3] }.freeze,
    { name: :customer_feedback, field_type: :dropdown, expect_from_to: false, data_type: :Integer,
      invalid_rule_types: [1, 3] }.freeze,
    { name: :mail_del_failed_requester, field_type: :label, expect_from_to: false,
      invalid_rule_types: [1, 3] }.freeze,
    { name: :mail_del_failed_others, field_type: :label, expect_from_to: false,
      invalid_rule_types: [1, 3] }.freeze,
    { name: :response_due, field_type: :label, expect_from_to: false,
      invalid_rule_types: [1, 3] }.freeze,
    { name: :resolution_due, field_type: :label, expect_from_to: false,
      invalid_rule_types: [1, 3] }.freeze
  ].freeze

  CUSTOM_FIELD_EVENT_HASH = {
    nested_field: { field_type: :nested_field, data_type: :String, expect_from_to: true, custom_field: true,
                    invalid_rule_types: [1, 3] }.freeze,
    custom_dropdown: { field_type: :dropdown, data_type: :String, expect_from_to: true, custom_field: true,
                       invalid_rule_types: [1, 3] }.freeze,
    custom_checkbox: { field_type: :dropdown, data_type: :Integer, expect_from_to: false, custom_field: true,
                       invalid_rule_types: [1, 3] }.freeze, # need to make integer after frontend validation done
  }.freeze

  EVENT_ANY_FIELDS = %i[priority ticket_type status group_id responder_id note_type customer_feedback].freeze
  EVENT_NONE_FIELDS = %i[group_id responder_id].freeze
  EVENT_NOTE_TYPE = %w[public private --].freeze
end
