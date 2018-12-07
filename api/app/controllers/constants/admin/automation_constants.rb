module Admin::AutomationConstants
  VALIDATION_CLASS = 'Admin::AutomationValidation'.freeze

  INDEX_FIELDS = %i[rule_type].freeze

  AUTOMATION_FIELDS = {
    dispatcher: [:conditions, :actions],
    observer: [:performer, :events, :conditions, :actions]
  }.freeze

  EVENT_NESTED_FIELDS = %i[nested_rule nested_rules from_nested_rules to_nested_rules].freeze

  EVENT_COMMON_FIELDS = %i[from to value rule_type].freeze + EVENT_NESTED_FIELDS

  CONDITON_SET_NESTED_FIELDS = %i[nested_rules].freeze

  CONDITION_SET_COMMON_FIELDS = %i[operator value rule_type].freeze + CONDITON_SET_NESTED_FIELDS

  ACTION_COMMON_FIELDS = %i[value email_to email_subject email_body request_type 
                      url need_authentication username password api_key custom_headers 
                      content_layout params].freeze

  NESTED_DATA_COMMON_FIELDS = %i[value from to].freeze
    
  EVENT_FIELDS = %i[name] + EVENT_COMMON_FIELDS

  PERFORMER_FIELDS = %i[type members].freeze

  CONDITION_SET_FIELDS = %i[name] + CONDITION_SET_COMMON_FIELDS

  ACTION_FIELDS = %i[name] + ACTION_COMMON_FIELDS

  NESTED_DATA_FIELDS = %i[name] + NESTED_DATA_COMMON_FIELDS

  EVALUATE_ON_MAPPING = { contact: :requester, company: :company, ticket: :ticket }.freeze

  EVALUATE_ON_MAPPING_INVERT = EVALUATE_ON_MAPPING.invert

  DEFAULT_OPERATOR = 'all'.freeze

  MASKED_FIELDS = { password: '' }.freeze
end.freeze
