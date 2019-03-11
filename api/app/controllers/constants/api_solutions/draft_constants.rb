module ApiSolutions::DraftConstants
  VALIDATION_CLASS = 'ApiSolutions::DraftValidation'.freeze
  DELEGATOR_CLASS = 'ApiSolutions::DraftDelegator'.freeze
  INDEX_FIELDS = %w[portal_id].freeze
  RECENT_DRAFTS_LIMIT = 3
end
