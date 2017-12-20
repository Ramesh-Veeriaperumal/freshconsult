module IntegratedUserConstants
  INDEX_FIELDS = %w(installed_application_id user_id username password).freeze
  VALIDATION_CLASS = 'IntegratedUserValidation'.freeze
  LOAD_OBJECT_EXCEPT = %w(user_credentials_add user_credentials_remove).freeze
end.freeze
