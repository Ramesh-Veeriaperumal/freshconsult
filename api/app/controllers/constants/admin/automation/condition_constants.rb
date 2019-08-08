module Admin::Automation::ConditionConstants
  include Admin::Automation::Condition::TicketFieldConstants
  include Admin::Automation::Condition::ContactFieldConstants
  include Admin::Automation::Condition::CompanyFieldConstants

  FIELD_TYPE = {
    text: %i[is is_not contains does_not_contain starts_with ends_with is_any_of is_none_of],
    old_text: %i[is is_not contains does_not_contain starts_with ends_with],
    paragraph: %i[is is_not contains does_not_contain starts_with ends_with is_any_of is_none_of],
    email: %i[is is_not contains does_not_contain is_any_of is_none_of],
    old_email: %i[is is_not contains does_not_contain],
    add_note_type: %i[is is_not contains does_not_contain is_any_of is_none_of],
    checkbox: %i[selected not_selected],
    choicelist: %i[in not_in],
    dropdown: %i[in not_in],
    dropdown_blank: %i[in not_in],
    number: %i[is is_not greater_than less_than is_any_of is_none_of],
    decimal: %i[is is_not greater_than less_than],
    hours: %i[is greater_than less_than],
    nested_field: %i[is is_not is_any_of is_none_of],
    supervisor_nested_field: %i[is],
    greater: %i[greater_than],
    object_id: %i[in not_in],
    date_time: %i[during greater_than less_than],
    date_time_status: %i[during is greater_than less_than],
    date: %i[is is_not greater_than less_than],
    tags: %i[in not_in and],
    url: %i[is is_not contains does_not_contain starts_with ends_with is_any_of is_none_of],
    phone_number: %i[is is_not contains does_not_contain starts_with ends_with is_any_of is_none_of],
    freddy_field_type: %i[is is_not]
  }.freeze

  EMAIL_FIELD_TYPE = %i[email old_email].freeze

  SUPERVISOR_FIELD_TYPE = {
    text: :old_text,
    email: :old_email,
    number: :decimal,
    nested_field: :supervisor_nested_field
  }.freeze

  ARRAY_VALUE_EXPECTING_OPERATOR = %i[contains_all_of does_not_contain contains
                                      is_any_of is_none_of in not_in all starts_with ends_with].freeze

  SINGLE_VALUE_EXPECTING_OPERATOR = %i[is is_not greater_than less_than during].freeze

  SUPERVISOR_SINGLE_VALUE_OPERATOR = %i[contains does_not_contain starts_with ends_with].freeze

  NO_VALUE_EXPECTING_OPERATOR = %i[selected not_selected].freeze
end
