config = File.join(Rails.root, 'config', 'integrations_config.yml')
key_hash = (YAML::load_file config)["xero"]
XERO_CONSUMER_KEY = key_hash["consumer_key"]
XERO_CONSUMER_SECRET = key_hash["consumer_secret"]
XERO_PATH_TO_PRIVATE_KEY = File.join(Rails.root,'config','cert','integrations','xero','privatekey.pem');
XERO_PATH_TO_SSL_CLIENT_CERT = File.join(Rails.root,'config' ,'cert','integrations','xero', 'entrust-cert.pem')
XERO_PATH_TO_SSL_CLIENT_KEY = File.join(Rails.root,'config' ,'cert','integrations','xero', 'entrust-private-nopass.pem')
INVALID_XERO_CURRLIAB = [ "800", "801" , "877"]
INVALID_XERO_EXPENSE = [ "497", "498" , "499"]
INVALID_XERO_CODE = 620