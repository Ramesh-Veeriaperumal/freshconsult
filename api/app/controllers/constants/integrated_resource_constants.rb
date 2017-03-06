module IntegratedResourceConstants
  INDEX_FIELDS  = %w(installed_application_id local_integratable_id local_integratable_type).freeze | ApiConstants::DEFAULT_PARAMS | ApiConstants::DEFAULT_INDEX_FIELDS
  CREATE_FIELDS = %w(application_id local_integratable_id local_integratable_type remote_integratable_id remote_integratable_type installed_application_id).freeze | ApiConstants::DEFAULT_PARAMS
  VALIDATION_CLASS = 'IntegratedResourceValidation'.freeze
end.freeze