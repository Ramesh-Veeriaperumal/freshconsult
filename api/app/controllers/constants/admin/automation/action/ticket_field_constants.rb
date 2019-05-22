module Admin::Automation::Action::TicketFieldConstants
  ACTION_FIELDS_HASH = [
    { name: :priority, field_type: :dropdown, data_type: :Integer,
      invalid_rule_types: [] }.freeze,
    { name: :ticket_type, field_type: :dropdown, data_type: :String,
      invalid_rule_types: [] }.freeze,
    { name: :status, field_type: :dropdown, data_type: :Integer,
      invalid_rule_types: [] }.freeze,
    { name: :add_tag, field_type: :dropdown, data_type: :Array, multiple: true, value: String,
      invalid_rule_types: [] }.freeze,
    { name: :add_a_cc, field_type: :text, data_type: :String, non_unique_field: true,
      invalid_rule_types: [3, 4] }.freeze,
    { name: :trigger_webhook, field_type: :webhook, data_type: :Integer,
      invalid_rule_types: [3] }.freeze,
    { name: :add_watcher, field_type: :dropdown, value: :Integer, multiple: true, data_type: Array,
      invalid_rule_types: [] }.freeze,
    { name: :add_comment, field_type: :text, data_type: String, non_unique_field: true,
      invalid_rule_types: [1, 3, 4] }.freeze,
    { name: :responder_id, field_type: :dropdown, data_type: :Integer,
      invalid_rule_types: [] }.freeze,
    { name: :product_id, field_type: :dropdown, data_type: :Integer,
      invalid_rule_types: [] }.freeze,
    { name: :group_id, field_type: :dropdown, data_type: :Integer,
      invalid_rule_types: [] }.freeze,
    { name: :send_email_to_group, field_type: :email, data_type: :Integer,
      invalid_rule_types: [] }.freeze,
    { name: :send_email_to_agent, field_type: :email, data_type: :Integer,
      invalid_rule_types: [] }.freeze,
    { name: :send_email_to_requester, field_type: :email, data_type: :Integer,
      invalid_rule_types: [] }.freeze,
    { name: :add_note, field_type: :add_note_type, data_type: String,
      invalid_rule_types: [3] }.freeze,
    { name: :forward_ticket, field_type: :forward_note, data_type: :Integer,
      invalid_rule_types: [3] }.freeze,
    { name: :delete_ticket, field_type: :label,
      invalid_rule_types: [] }.freeze,
    { name: :mark_as_spam, field_type: :label,
      invalid_rule_types: [] }.freeze,
    { name: :skip_notification, field_type: :label,
      invalid_rule_types: [3, 4] }.freeze,
    { name: :marketplace_app_slack_v2, field_type: :slack,
      invalid_rule_types: [3] }.freeze,
    { name: :marketplace_app_office_365, field_type: :office365,
      invalid_rule_types: [3] }.freeze
  ].freeze

  CUSTOM_FIELD_ACTION_HASH = {
    nested_field: { field_type: :nested_field, data_type: :String }.freeze,
    custom_dropdown: { field_type: :dropdown, data_type: :String }.freeze,
    custom_checkbox: { field_type: :dropdown, data_type: :Integer }.freeze,
    custom_text: { field_type: :text, data_type: :String }.freeze,
    custom_paragraph: { field_type: :text, data_type: :String }.freeze,
    custom_number: { field_type: :text, data_type: :String, allow_any_type: true }.freeze, # data type should be number and should be changed after frontend validation
    custom_decimal: { field_type: :text, data_type: :Float, allow_any_type: true }.freeze, # data type should be number and should be changed after frontend validation
    custom_date: { field_type: :text, data_type: :String }.freeze
  }.freeze

  ACTION_NONE_FIELDS = %i[responder_id product_id group_id].freeze
end
