module Integrations 
	config = File.join(Rails.root, 'config', 'integrations_config.yml')
	hash = (YAML::load_file config)
	#========================================================
	xero_key_hash = hash["xero"]
	XERO_CONSUMER_KEY = xero_key_hash["consumer_key"]
	XERO_CONSUMER_SECRET = xero_key_hash["consumer_secret"]
	XERO_PATH_TO_PRIVATE_KEY = File.join(Rails.root,'config','cert','integrations','xero','privatekey.pem');
	XERO_PATH_TO_SSL_CLIENT_CERT = File.join(Rails.root,'config' ,'cert','integrations','xero', 'entrust-cert.pem')
	XERO_PATH_TO_SSL_CLIENT_KEY = File.join(Rails.root,'config' ,'cert','integrations','xero', 'entrust-private-nopass.pem')
	#========================================================
end