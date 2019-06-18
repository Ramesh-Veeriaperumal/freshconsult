module Integrations::Quickbooks::Constant

  ACCESS_TOKEN_RENEWAL_URI = 'https://appcenter.intuit.com/api/v1/connection/reconnect'.freeze

  DISCONNECT_URI = 'https://appcenter.intuit.com/api/v1/connection/disconnect'.freeze

  OPENID_URL = 'https://openid.intuit.com/openid/xrds'.freeze
	# renew the access token after 150 days
	TOKEN_RENEWAL_DAYS = 151

  INTUIT_OPEN_ID_HOST = 'openid.intuit.com'.freeze
end
