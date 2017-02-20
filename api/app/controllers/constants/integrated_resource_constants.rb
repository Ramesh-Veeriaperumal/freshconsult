module IntegratedResourceConstants
  INDEX_FIELDS  = %w(installed_application_id local_integratable_id local_integratable_type).freeze | ApiConstants::DEFAULT_PARAMS | ApiConstants::DEFAULT_INDEX_FIELDS
  VALIDATION_CLASS = 'IntegratedResourceValidation'.freeze
end.freeze