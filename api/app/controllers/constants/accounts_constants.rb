module AccountsConstants
  CANCEL_FIELDS = %w[cancellation_feedback].freeze
  DOWNLOAD_FILE_FIELDS = %w[type].freeze
  VALIDATION_CLASS = 'AccountValidation'.freeze
  DELEGATOR_CLASS = 'AccountDelegator'.freeze
  WRAP_PARAMS = [:api_account,include: [:cancellation_feedback], exclude: [], format: [:json]].freeze
  VALID_DOWNLOAD_TYPES = ['beacon'].freeze
  DOWNLOAD_TYPE_TO_METHOD_MAP = { beacon: :beacon_report }.freeze
end.freeze