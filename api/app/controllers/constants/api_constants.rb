module ApiConstants
  # ControllerConstants
  API_CURRENT_VERSION = 'v2'

  DEFAULT_PAGINATE_OPTIONS = {
    per_page: 50,
    max_per_page: 100,
    page: 1
  }

  DEFAULT_PARAMS = %w(version format k id)
  DEFAULT_INDEX_FIELDS = %w(version format k id per_page page)
  UPLOADED_FILE_TYPE = ActionDispatch::Http::UploadedFile

  DELETED_SCOPE = {
    'update' => false,
    'restore' => true,
    'destroy' => false,
    'time_sheets' => false
  }

  TIME_UNITS = %w(hours minutes seconds) # do not change the order.

  # ValidationConstants
  BOOLEAN_VALUES = [true, false, 'true', 'false'] # for boolean fields all these values are accepted.
  CC_EMAIL_REGEX = /\b[-a-zA-Z0-9.'’&_%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,15}\b/
  EMAIL_REGEX = AccountConstants::EMAIL_REGEX
  ALLOWED_ATTACHMENT_SIZE = 15 * 1024 * 1024

  LOAD_OBJECT_EXCEPT = [:create, :index, :route_not_found, :filtered_index] +
                       TimeSheetConstants::LOAD_OBJECT_EXCEPT +
                       NoteConstants::LOAD_OBJECT_EXCEPT +
                       DiscussionConstants::LOAD_OBJECT_EXCEPT

  ALLOWED_DOMAIN = AppConfig['base_domain'][Rails.env]
end
