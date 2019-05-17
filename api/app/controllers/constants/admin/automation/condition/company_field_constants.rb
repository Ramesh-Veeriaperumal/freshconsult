module Admin::Automation::Condition::CompanyFieldConstants
  CONDITION_COMPANY_FIELDS_HASH = [
    { name: :domains, field_type: :text, data_type: :String,
      invalid_rule_types: [3] }.freeze,
    { name: :name, field_type: :text, data_type: :String,
      invalid_rule_types: [3] }.freeze,
    { name: :segments, field_type: :object_id, data_type: :Integer,
      invalid_rule_types: [3] }.freeze,
    { name: :health_score, field_type: :choicelist, data_type: :String,
      invalid_rule_types: [3] }.freeze,
    { name: :account_tier, field_type: :object_id, data_type: :String,
      invalid_rule_types: [3] }.freeze,
    { name: :industry, field_type: :object_id, data_type: :String,
      invalid_rule_types: [3] }.freeze,
    { name: :renewal_date, field_type: :date, data_type: :String,
      invalid_rule_types: [3] }.freeze
  ].freeze

  CUSTOM_CONDITION_COMPANY_HASH = {
    custom_dropdown: { field_type: :dropdown, data_type: :String, custom_field: true,
                       invalid_rule_types: [3] }.freeze,
    custom_checkbox: { field_type: :checkbox, data_type: :String, custom_field: true,
                       invalid_rule_types: [3] }.freeze,
    custom_text: { field_type: :text, data_type: :String, custom_field: true,
                   invalid_rule_types: [3] }.freeze,
    custom_url: { field_type: :url, data_type: :String, custom_field: true,
                  invalid_rule_types: [3] }.freeze,
    custom_paragraph: { field_type: :text, data_type: :String, custom_field: true,
                        invalid_rule_types: [3] }.freeze,
    custom_number: { field_type: :number, data_type: :String, custom_field: true, allow_any_type: true,
                     invalid_rule_types: [3] }.freeze, # data type should be number and should be changed after frontend validation
    custom_phone_number: { field_type: :text, data_type: :String, custom_field: true,
                           invalid_rule_types: [3] }.freeze, # data type should be number and should be changed after frontend validation
    custom_date: { field_type: :date, data_type: :String, custom_field: true,
                   invalid_rule_types: [3] }.freeze
  }.freeze
end
