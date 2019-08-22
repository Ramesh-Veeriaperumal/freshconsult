module Notifications::Email::BccConstants
  VALIDATION_CLASS = 'Notifications::Email::BccValidation'.freeze
  UPDATE_FIELDS = %w[emails].freeze
  FIELD_MAPPING = {
    base: :emails
  }.freeze
end
