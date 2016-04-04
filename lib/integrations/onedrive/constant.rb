module Integrations::Onedrive::Constant
	ONEDRIVE_REST_API = "https://login.live.com/oauth20_token.srf"
	ONEDRIVE_VIEW_API = "https://api.onedrive.com"
	ONEDRIVE_HOST = "api.onedrive.com"	
	ONEDRIVE_TOKEN_TYPE = CGI.escape("bearer")
	ONEDRIVE_TOKEN_EXPIRES_IN = 3600
	USER_ID = "user_id"
	STATE ="state"
	COOKIE ="response_method%3Dcookie"
	URL = "response_method%3Durl"
	ONEDRIVE_SCOPE = "wl.skydrive wl.signin onedrive.readwrite"
end