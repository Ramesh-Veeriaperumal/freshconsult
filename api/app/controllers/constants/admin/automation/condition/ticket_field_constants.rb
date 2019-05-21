module Admin::Automation::Condition::TicketFieldConstants
  CONDITION_TICKET_FIELDS_HASH = [
    { name: :from_email, field_type: :email, data_type: :String,
      invalid_rule_types: [] }.freeze,
    { name: :to_email, field_type: :email, data_type: :String,
      invalid_rule_types: [] }.freeze,
    { name: :ticket_cc, field_type: :email, data_type: :String,
      invalid_rule_types: [3, 4] }.freeze,
    { name: :ticlet_cc, field_type: :email, data_type: :String,
      invalid_rule_types: [3, 4] }.freeze,
    { name: :ticket_type, field_type: :object_id, data_type: :String,
      invalid_rule_types: [] }.freeze,
    { name: :status, field_type: :object_id, data_type: :Integer,
      invalid_rule_types: [] }.freeze,
    { name: :priority, field_type: :object_id, data_type: :Integer,
      invalid_rule_types: [] }.freeze,
    { name: :source, field_type: :object_id, data_type: :Integer,
      invalid_rule_types: [] }.freeze,
    { name: :product_id, field_type: :object_id, data_type: :Integer,
      invalid_rule_types: [] }.freeze,
    { name: :group_id, field_type: :object_id, data_type: :Integer,
      invalid_rule_types: [] }.freeze,
    { name: :responder_id, field_type: :object_id, data_type: :Integer,
      invalid_rule_types: [] }.freeze,
    { name: :internal_group_id, field_type: :object_id, data_type: :Integer,
      invalid_rule_types: [3] }.freeze,
    { name: :internal_agent_id, field_type: :object_id, data_type: :Integer,
      invalid_rule_types: [3] }.freeze,
    { name: :tag_names, field_type: :tags, data_type: :String,
      invalid_rule_types: [3] }.freeze,
    { name: :subject, field_type: :text, data_type: :String,
      invalid_rule_types: [] }.freeze,
    { name: :subject_or_description, field_type: :text, data_type: :String,
      invalid_rule_types: [3] }.freeze,
    { name: :description, field_type: :text, data_type: :String,
      invalid_rule_types: [3] }.freeze,
    { name: :last_interaction, field_type: :text, data_type: :String,
      invalid_rule_types: [1, 3] }.freeze,
    { name: :created_at, field_type: :date_time, data_type: :String,
      invalid_rule_types: [3, 4] }.freeze,
    { name: :updated_at, field_type: :date_time, data_type: :String,
      invalid_rule_types: [1, 3] }.freeze,
    { name: :inbound_count, field_type: :number, data_type: :Integer, allow_any_type: true,
      invalid_rule_types: [1] }.freeze,
    { name: :outbound_count, field_type: :number, data_type: :Integer, allow_any_type: true,
      invalid_rule_types: [1] }.freeze,

    { name: :hours_since_created, field_type: :hours, data_type: :Integer,
      invalid_rule_types: [1, 4] }.freeze,
    { name: :pending_since, field_type: :hours, data_type: :Integer,
      invalid_rule_types: [1, 4] }.freeze,
    { name: :resolved_at, field_type: :hours, data_type: :Integer,
      invalid_rule_types: [1, 4] }.freeze,
    { name: :closed_at, field_type: :hours, data_type: :Integer,
      invalid_rule_types: [1, 4] }.freeze,
    { name: :opened_at, field_type: :hours, data_type: :Integer,
      invalid_rule_types: [1, 4] }.freeze,
    { name: :first_assigned_at, field_type: :hours, data_type: :Integer,
      invalid_rule_types: [1, 4] }.freeze,
    { name: :assigned_at, field_type: :hours, data_type: :Integer,
      invalid_rule_types: [1, 4] }.freeze,
    { name: :requester_responded_at, field_type: :hours, data_type: :Integer,
      invalid_rule_types: [1, 4] }.freeze,
    { name: :agent_responded_at, field_type: :hours, data_type: :Integer,
      invalid_rule_types: [1, 4] }.freeze,
    { name: :frDueBy, field_type: :hours, data_type: :Integer,
      invalid_rule_types: [1, 4] }.freeze,
    { name: :due_by, field_type: :hours, data_type: :Integer,
      invalid_rule_types: [1, 4] }.freeze,
    { name: :company_name, field_type: :text, data_type: :String,
      invalid_rule_types: [1, 4] }.freeze,
    { name: :contact_name, field_type: :old_text, data_type: :String,
      invalid_rule_types: [1, 4] }.freeze,
    { name: :freddy_suggestion, field_type: :freddy_field_type, data_type: :String,
      invalid_rule_types: [1, 3] }.freeze
  ].freeze

  CUSTOM_FIELD_CONDITION_HASH = {
    nested_field: { field_type: :nested_field, data_type: :String, custom_field: true,
                    invalid_rule_types: [] }.freeze,
    custom_dropdown: { field_type: :object_id, data_type: :String, custom_field: true,
                       invalid_rule_types: [] }.freeze,
    custom_checkbox: { field_type: :checkbox, data_type: :String, custom_field: true,
                       invalid_rule_types: [] }.freeze,
    custom_text: { field_type: :text, data_type: :String, custom_field: true,
                   invalid_rule_types: [] }.freeze,
    custom_paragraph: { field_type: :text, data_type: :String, custom_field: true,
                        invalid_rule_types: [3] }.freeze,
    custom_number: { field_type: :number, data_type: :String, custom_field: true, allow_any_type: true,
                     invalid_rule_types: [] }.freeze, # data type should be number and should be changed after frontend validation
    custom_decimal: { field_type: :decimal, data_type: :Float, custom_field: true, allow_any_type: true,
                      invalid_rule_types: [] }.freeze, # data type should be number and should be changed after frontend validation
    custom_date: { field_type: :date, data_type: :String, custom_field: true,
                   invalid_rule_types: [] }.freeze
  }.freeze

  CONDITION_NONE_FIELDS = %i[ticket_type product_id group_id responder_id internal_group_id
                             internal_agent_id health_score account_tier industry].freeze
end
