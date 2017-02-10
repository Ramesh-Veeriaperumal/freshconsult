module IntegratedUserConstants
  INDEX_FIELDS  = %w(installed_application_id user_id).freeze | ApiConstants::DEFAULT_PARAMS | ApiConstants::DEFAULT_INDEX_FIELDS
  VALIDATION_CLASS = 'IntegratedUserValidation'.freeze
end.freeze