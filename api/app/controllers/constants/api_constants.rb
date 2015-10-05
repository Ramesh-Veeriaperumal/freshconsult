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

  TIME_UNITS = %w(hours minutes seconds) # do not change the order.

  DEMOSITE_URL = AppConfig['demo_site'][Rails.env]

  # ValidationConstants
  EMAIL_REGEX = AccountConstants::EMAIL_REGEX
  EMAIL_VALIDATOR = AccountConstants::EMAIL_VALIDATOR
  ALLOWED_ATTACHMENT_SIZE = 15 * 1024 * 1024

  LOAD_OBJECT_EXCEPT = [:create, :index, :route_not_found, :filtered_index] +
                       TimeEntryConstants::LOAD_OBJECT_EXCEPT +
                       NoteConstants::LOAD_OBJECT_EXCEPT +
                       DiscussionConstants::LOAD_OBJECT_EXCEPT

  ALLOWED_DOMAIN = AppConfig['base_domain'][Rails.env]
  MAX_LENGTH_STRING = 255

  # Wrap parameters args
  WRAP_PARAMS = [exclude: [], format: :json]
end
