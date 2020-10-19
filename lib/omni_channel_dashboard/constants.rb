# frozen_string_literal: true

module OmniChannelDashboard::Constants
  JWT_ALGO = 'HS256'
  EXPIRY_DURATION = 120.seconds.freeze
  ISSUER = 'freshdesk'
  SUCCESS = [204].freeze
  ACCOUNT_UPDATE_API_PATH = '/api/data/accounts/'
  ACCOUNT_CREATE_API_PATH = '/api/data/accounts'
  DEFAULT_TIMEOUT = 10
  BASE_URL = (TOUCHSTONE_CONFIG['api_endpoint'] + '/api/data/custom-widget-data?').freeze
  ERROR_RESPONSE = { error_type: 'BAD_GATEWAY', message: 'Failed to handle the request' }.freeze
  GMT_OFFSET = 'GMT'
end
