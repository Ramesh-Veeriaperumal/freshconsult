module CannedFormConstants
  VALIDATION_CLASS = 'CannedFormValidation'.freeze
  DEFAULT_FIELDS = %w[name welcome_text thankyou_text fields version].freeze
  CREATE_FIELDS = DEFAULT_FIELDS
  UPDATE_FIELDS = DEFAULT_FIELDS
  CREATE_HANDLE_FIELDS = [:ticket_id].freeze

  MAX_NO_OF_FORMS = 20
  MIN_FIELD_LIMIT = 1
  MAX_FIELD_LIMIT = 20
  MIN_CHOICE_LIMIT = 2
  MAX_CHOICE_LIMIT = 50
  SUPPORTED_FIELDS = Admin::CannedForm::CUSTOM_FIELDS_SUPPORTED.map(&:to_s)
  FIELD_NAME_REGEX = /^(#{SUPPORTED_FIELDS.join('|')})_/
  MULTI_CHOICE_FIELDS = ['dropdown'].freeze
end
