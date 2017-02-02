module IntegratedResourceConstants
  INDEX_FIELDS  = %w(installed_application_id ticket_id).freeze | ApiConstants::DEFAULT_PARAMS | ApiConstants::DEFAULT_INDEX_FIELDS
  VALIDATION_CLASS = 'IntegratedResourceValidation'.freeze
end.freeze