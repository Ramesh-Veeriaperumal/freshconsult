module ApiConstants
  # ControllerConstants
  API_CURRENT_VERSION = 'v2'

  DEFAULT_PAGINATE_OPTIONS = {
    per_page: 50,
    max_per_page: 100,
    page: 1
  }

  DEFAULT_PARAMS = [:version, :format, :k, :id].map(&:to_s)
  DEFAULT_INDEX_FIELDS = [:per_page, :page]
  UPLOADED_FILE_TYPE = ActionDispatch::Http::UploadedFile

  DELETED_SCOPE = {
    'update' => false,
    'assign' => false,
    'restore' => true,
    'destroy' => false,
    'time_sheets' => false
  }

  TIME_UNITS = %w(hours minutes seconds) # do not change the order.

  # ValidationConstants
  BOOLEAN_VALUES = [true, false, 'true', 'false'] # for boolean fields all these values are accepted.
  EMAIL_REGEX = /\b[-a-zA-Z0-9.'’&_%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,15}\b/
  ALLOWED_ATTACHMENT_SIZE = 15 * 1024 * 1024
end
