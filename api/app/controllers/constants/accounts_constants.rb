module AccountsConstants
  CANCEL_FIELDS = %w[cancellation_feedback].freeze
  DOWNLOAD_FILE_FIELDS = %w[type].freeze
  VALIDATION_CLASS = 'AccountValidation'.freeze
  DELEGATOR_CLASS = 'AccountDelegator'.freeze
  WRAP_PARAMS = [:api_account,include: [:cancellation_feedback], exclude: [], format: [:json]].freeze
  VALID_DOWNLOAD_TYPES = ['beacon'].freeze
  DOWNLOAD_TYPE_TO_METHOD_MAP = { beacon: :beacon_report }.freeze
  CONTACTS_URL = "#{PRODUCT_FEEDBACK_CONFIG['feedback_account']}/#{PRODUCT_FEEDBACK_CONFIG['contacts_path']}?email=%{user_email}"
  TICKET_URL_WITH_COMPANY = "#{PRODUCT_FEEDBACK_CONFIG['feedback_account']}/#{PRODUCT_FEEDBACK_CONFIG['tickets_path']}?company_id=%{company_id}&per_page=%{per_page_count}&updated_since=%{updated_since_date}"
  TICKET_URL_WITHOUT_COMPANY = "#{PRODUCT_FEEDBACK_CONFIG['feedback_account']}/#{PRODUCT_FEEDBACK_CONFIG['tickets_path']}?requester_id=%{requester_id}&per_page=%{per_page_count}&updated_since=%{updated_since_date}"
end.freeze
