module ApiSolutions::DraftConstants
  VALIDATION_CLASS = 'ApiSolutions::DraftValidation'.freeze
  DELEGATOR_CLASS = 'ApiSolutions::DraftDelegator'.freeze
  INDEX_FIELDS = %w[portal_id].freeze
  AUTOSAVE_FIELDS = %w[title description timestamp].freeze
  UPDATE_FIELDS = %w[title description user_id modified_at last_updated_at].freeze
  DRAFT_NEEDED_ACTIONS = %w[update destroy].freeze
  RECENT_DRAFTS_LIMIT = 3
end
