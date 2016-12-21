module EhawkConfig
	ehawk_credential = (YAML::load_file(File.join(Rails.root, 'config', 'ehawk_api.yml')))[Rails.env]

	API_KEY = ehawk_credential['api_key']

    URL = ehawk_credential['url']
end
