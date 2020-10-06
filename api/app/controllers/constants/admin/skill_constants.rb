module Admin::SkillConstants

  REQUEST_PERMITTED_PARAMS = %i[name rank agents match_type conditions].freeze

  CONDITION_DB_KEYS = %i[evaluate_on name operator value nested_rules].freeze

  CONDITION_PARAMS = %i[resource_type field_name operator value nested_fields].freeze

  MATCH_TYPES = %w[any all].freeze

  EVALUATE_ON_MAPPINGS = { requester: :contact, company: :company, ticket: :ticket }.freeze

  EVALUATE_ON_MAPPINGS_INVERT = EVALUATE_ON_MAPPINGS.invert.freeze

  CONSTRUCT_FIELDS = CONDITION_DB_KEYS - %i[operator].freeze

  NESTED_DATA_FIELDS = %i[name value].freeze

  DEFAULT_RESOURCE_TYPE = :ticket.freeze

  DEFAULT_MATCH_TYPE = 'all'.freeze

  CUSTOM_FIELDS_FOR_SKILLS = %i[custom_dropdown nested_field].freeze

  LEVELS = %i[level2 level3].freeze

  SOURCE_IDS = Helpdesk::Source.default_ticket_source_token_by_key.keys.freeze

  ANY_NONE = ['', '--'].freeze

  NONE_VALUE = [''].freeze

  DELEGATOR_FIELDS = %i[name filter_data].freeze

  LANGUAGE_CODES = I18n.available_locales_with_name.each_with_object({}) do |arr, hash|
    hash[arr.last.to_s] = arr.first
  end.keys.freeze

  CONDITIONS_OPERATORS = {
      array_type: %i[in not_in],
      single_element: %i[is]
  }

  CONDITION_FIELDS = {
      ticket: %i[priority ticket_type source product_id group_id].freeze,
      contact: %i[language].freeze,
      company: %i[name domains].freeze
  }

  FIELD_NAME_CHANGE_MAPPINGS = {
      evaluate_on: :resource_type,
      name: :field_name,
      operator: :operator,
      value: :value,
      nested_rules: :nested_fields
  }.freeze

  FIELD_NAME_CHANGE_MAPPINGS_INVERT = FIELD_NAME_CHANGE_MAPPINGS.invert.freeze

  OBJECT_FROM_DB_ACTIONS = %i[create update].freeze

  TICKET_CUSTOM_FIELD_TYPES = %i[nested_field object_id].freeze

  CUSTOMER_CUSTOM_FIELD_TYPES = %i[object_id dropdown].freeze

end.freeze