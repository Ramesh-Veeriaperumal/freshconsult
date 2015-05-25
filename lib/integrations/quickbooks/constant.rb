module Integrations::Quickbooks::Constant

	ACCESS_TOKEN_RENEWAL_URI = "https://appcenter.intuit.com/api/v1/connection/reconnect"
 	OPENID_URL = "https://openid.intuit.com/openid/xrds"
	# renew the access token after 150 days
	TOKEN_RENEWAL_DAYS = 151

end
