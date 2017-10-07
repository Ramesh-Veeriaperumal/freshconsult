module TicketTemplateConstants

  INDEX_FIELDS = %w(type filter).freeze
  FILTER_ALLOWED_VALUES = %w(accessible)
  ALLOWED_TYPE_VALUES   = %W(prime only_parent)

  VALIDATION_CLASS = 'TicketTemplateValidation'.freeze

end
