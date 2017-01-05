module TodoConstants
  CREATE_FIELDS = %w(body ticket_id).freeze | ApiConstants::DEFAULT_PARAMS
  UPDATE_FIELDS = %w(body completed).freeze | ApiConstants::DEFAULT_PARAMS
  INDEX_FIELDS  = %w(ticket_id).freeze | ApiConstants::DEFAULT_PARAMS | ApiConstants::DEFAULT_INDEX_FIELDS
  SHOW_FIELDS = ApiConstants::DEFAULT_PARAMS
  PARAMS_MAPPINGS = { completed: :deleted }.freeze
  VALIDATION_CLASS = 'TodoValidation'.freeze
end.freeze
