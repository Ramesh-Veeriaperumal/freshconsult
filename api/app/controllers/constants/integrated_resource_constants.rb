module IntegratedResourceConstants
  INDEX_FIELDS  = %w(installed_application_id local_integratable_id).freeze | ApiConstants::DEFAULT_PARAMS | ApiConstants::DEFAULT_INDEX_FIELDS
  VALIDATION_CLASS = 'IntegratedResourceValidation'.freeze
end.freeze