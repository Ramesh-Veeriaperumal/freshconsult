module Channel::V2::Iam::AuthenticationConstants
  BEARER = 'Bearer'
  ALLOWED_GRANT_TYPES = ['authz.freshworks.com/access-token'].freeze
  DEFAULT_REQUEST_PARAM_FIELDS = %w[version format].freeze
  IAM_AUTHENTICATE_TOKEN_FIELDS = (%w[grant_type user_id account_id account_domain client_id client_secret scope] + DEFAULT_REQUEST_PARAM_FIELDS).freeze
  VALIDATION_CLASS = 'AuthenticationValidation'.freeze
end
