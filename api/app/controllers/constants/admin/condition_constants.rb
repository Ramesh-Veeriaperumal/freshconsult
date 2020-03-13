module Admin::ConditionConstants
  include Admin::ConditionFieldConstants

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
    freddy_field_type: %i[is is_not],
    ticket_association_type: %i[is is_not]
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

  NESTED_EVENT_LABEL = %i[from_nested_field to_nested_field].freeze

  NESTED_LEVEL_COUNT = 2

  CONDITION_SET_NAMES = %w[condition_set_1 condition_set_2].freeze

  MAXIMUM_CONDITION_SET_COUNT = 2

  MAXIMUM_SUPERVISOR_CONDITION_SET_COUNT = 1

  CONDITION_RESOURCE_TYPES = %i[ticket contact company].freeze

  CONDITION_SET_PROPERTIES = %i[resource_type field_name operator value].freeze

  LEVELS = %i[level2 level3].freeze

  PERMITTED_DEFAULT_CONDITION_SET_VALUES = %i[field_name operator value].freeze

  PERMITTED_RELATED_CONDITION_SET_VALUES = (%i[related_conditions] + PERMITTED_DEFAULT_CONDITION_SET_VALUES).freeze

  BUSINESS_HOURS_FIELDS = %i[created_at updated_at].freeze

  ANY_NONE_VALUES = ['', '--', '##'].freeze

  CONDITION_SET_OPERATOR = %w[or and].freeze

  CUSTOM_FIELD_NONE_OR_ANY = %i[nested_field dropdown].freeze

  EMAIL_VALIDATOR_OPERATORS = %i[is is_not is_any_of is_none_of].freeze

  TICKET_ASSOCIATION_TYPES = [1, 2, 3, 4].freeze

  DISPATCHER_CONDITION_TICKET_ASSOCIATION_TYPES = [2, 3].freeze

  NESTED_RELATED_CONDITION_FIELD_NAME = ['out_of_office'].freeze

  GREATER_LESSER = ['greater_than', 'less_than'].freeze

  IS = ['is'].freeze
end
