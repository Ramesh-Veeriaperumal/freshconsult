module ProfileConstants
  UPDATE_FIELDS = %w(time_zone job_title language signature shortcuts_enabled).freeze
  USER_FIELDS = %w(time_zone job_title language).freeze
  VALIDATION_CLASS = 'ApiProfileValidation'.freeze
end.freeze
