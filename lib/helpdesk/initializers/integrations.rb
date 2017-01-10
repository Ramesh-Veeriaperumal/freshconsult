module Integrations 
	config = File.join(Rails.root, 'config', 'integrations_config.yml')
	hash = (YAML::load_file config)

  oauth_config = File.join(Rails.root, 'config', 'oauth_config.yml')
  oauth_yaml_hash = (YAML::load_file oauth_config)
  OAUTH_CONFIG_HASH = oauth_yaml_hash[Rails.env]
  OAUTH_OPTIONS_HASH = oauth_yaml_hash['oauth_options']
  MARKETPLACE_LANDING_PATH_HASH = hash['marketplace_landing_paths']
  API_KEYS = hash['api_keys']
	#========================================================
	xero_key_hash = hash["app"]["xero"]
	XERO_CONSUMER_KEY = xero_key_hash["consumer_key"]
	XERO_CONSUMER_SECRET = xero_key_hash["consumer_secret"]
	XERO_PATH_TO_PRIVATE_KEY = File.join(Rails.root,'config','cert','integrations','xero','privatekey.pem');
	XERO_PATH_TO_SSL_CLIENT_CERT = File.join(Rails.root,'config' ,'cert','integrations','xero', 'entrust-cert.pem')
	XERO_PATH_TO_SSL_CLIENT_KEY = File.join(Rails.root,'config' ,'cert','integrations','xero', 'entrust-private-nopass.pem')
	#========================================================
	onedrive_key_hash = hash["app"]["onedrive"]
	ONEDRIVE_CLIENT_ID = onedrive_key_hash["client_id"]
	ONEDRIVE_CLIENT_SECRET =  onedrive_key_hash["client_secret"]
	#========================================================
	icontact_key_hash = hash["app"]["icontact"]
	ICONTACT_APP_ID = icontact_key_hash["app_id"]
	#========================================================
  PROXY_SERVER = hash["proxy_server"] || {}
  cloud_elements_hash = hash["app"]["cloud_elements"][Rails.env]
  CLOUD_ELEMENTS_AUTH_HEADER = cloud_elements_hash["auth_header"]
  CRM_TO_HELPDESK_FORMULA_ID = cloud_elements_hash["crm_formula_template_id"]
  HELPDESK_TO_CRM_FORMULA_ID = cloud_elements_hash["fd_formula_template_id"]
end
