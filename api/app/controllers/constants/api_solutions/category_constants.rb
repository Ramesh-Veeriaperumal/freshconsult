module ApiSolutions::CategoryConstants
  DELEGATOR_CLASS = 'ApiSolutions::CategoryDelegator'.freeze
  VALIDATION_CLASS = 'ApiSolutions::CategoryValidation'.freeze
  INDEX_FIELDS = %w[language portal_id allow_language_fallback].freeze
  CREATE_FIELDS = %w[description name visible_in_portals].freeze
  UPDATE_FIELDS = %w[description name visible_in_portals].freeze
  REORDER_FIELDS = %w[position portal_id].freeze
end
