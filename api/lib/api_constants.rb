module ApiConstants
  # *********************************-- ControllerConstants --*********************************************

  API_CURRENT_VERSION = 'v2'
  DEFAULT_PAGINATE_OPTIONS = {
    per_page: 30,
    page: 1
  }
  DEFAULT_PARAMS = [:version, :format, :k].map(&:to_s)
  DEFAULT_INDEX_FIELDS = [:per_page, :page]
  UPLOADED_FILE_TYPE = ActionDispatch::Http::UploadedFile
  DELETED_SCOPE = {
    'update' => false,
    'assign' => false,
    'restore' => true,
    'destroy' => false,
    'time_sheets' => false
  }

  # *********************************-- ValidationConstants --*********************************************

  BOOLEAN_VALUES = ['0', 0, false, '1', 1, true, 'true', 'false'] # for boolean fields all these values are accepted.
  EMAIL_REGEX = /\b[-a-zA-Z0-9.'’&_%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,15}\b/
end
