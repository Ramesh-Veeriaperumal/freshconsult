module AccountsConstants
  CANCEL_FIELDS = %w[cancellation_feedback].freeze
  VALIDATION_CLASS = 'AccountValidation'.freeze
  DELEGATOR_CLASS = 'AccountDelegator'.freeze
  WRAP_PARAMS = [:api_account,include: [:cancellation_feedback], exclude: [], format: [:json]].freeze
end.freeze