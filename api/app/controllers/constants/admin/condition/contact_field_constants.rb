module Admin::Condition::ContactFieldConstants
  CONDITION_CONTACT_FIELDS_HASH = [
    { name: :email, field_type: :email, data_type: :String,
      invalid_rule_types: [3] }.freeze,
    { name: :name, field_type: :text, data_type: :String,
      invalid_rule_types: [3] }.freeze,
    { name: :job_title, field_type: :text, data_type: :String,
      invalid_rule_types: [3] }.freeze,
    { name: :time_zone, field_type: :choicelist, data_type: :String,
      invalid_rule_types: [3] }.freeze,
    { name: :language, field_type: :choicelist, data_type: :String,
      invalid_rule_types: [3] }.freeze,
    { name: :segments, field_type: :object_id, data_type: :Integer,
      invalid_rule_types: [3] }.freeze,
    { name: :twitter_profile_status, field_type: :checkbox, data_type: :String,
      invalid_rule_types: [3] }.freeze,
    { name: :twitter_followers_count, field_type: :number, data_type: :Integer,
      invalid_rule_types: [3] }.freeze
  ].freeze

  CUSTOM_CONDITION_CONTACT_HASH = {
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
