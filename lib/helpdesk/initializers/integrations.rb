module Integrations 
	config = File.join(Rails.root, 'config', 'integrations_config.yml')
	hash = (YAML::load_file config)

  oauth_config = File.join(Rails.root, 'config', 'oauth_config.yml')
  oauth_yaml_hash = (YAML::load_file oauth_config)
  OAUTH_CONFIG_HASH = oauth_yaml_hash[Rails.env]
  OAUTH_OPTIONS_HASH = oauth_yaml_hash['oauth_options']
	#========================================================
	xero_key_hash = hash["xero"]
	XERO_CONSUMER_KEY = xero_key_hash["consumer_key"]
	XERO_CONSUMER_SECRET = xero_key_hash["consumer_secret"]
	XERO_PATH_TO_PRIVATE_KEY = File.join(Rails.root,'config','cert','integrations','xero','privatekey.pem');
	XERO_PATH_TO_SSL_CLIENT_CERT = File.join(Rails.root,'config' ,'cert','integrations','xero', 'entrust-cert.pem')
	XERO_PATH_TO_SSL_CLIENT_KEY = File.join(Rails.root,'config' ,'cert','integrations','xero', 'entrust-private-nopass.pem')
	#========================================================
	onedrive_key_hash = hash["onedrive"]
	ONEDRIVE_CLIENT_ID = onedrive_key_hash["client_id"]
	ONEDRIVE_CLIENT_SECRET =  onedrive_key_hash["client_secret"]
	#========================================================
end
