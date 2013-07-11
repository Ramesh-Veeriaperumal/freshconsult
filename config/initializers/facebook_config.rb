module FacebookConfig
	config = File.join(Rails.root, 'config', 'facebook.yml')
	tokens = (YAML::load_file config)[Rails.env]

	APP_ID = tokens['app_id']
	SECRET_KEY = tokens['secret_key']
	CALLBACK_URL = tokens['callback_url']
end