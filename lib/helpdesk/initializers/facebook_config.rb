module FacebookConfig
	config = File.join(Rails.root, 'config', 'facebook.yml')
	tokens = (YAML::load_file config)[Rails.env]

	APP_ID = tokens['app_id']
	SECRET_KEY = tokens['secret_key']
	CALLBACK_URL = tokens['callback_url']
	PAGE_TAB_APP_ID = tokens['page_tab_app_id']
	PAGE_TAB_SECRET_KEY = tokens['page_tab_app_secret']
  
  Koala.config.api_version = "v2.2"
end
