module FacebookConfig
	config = File.join(Rails.root, 'config', 'facebook.yml')
	tokens = (YAML::load_file config)[Rails.env]

	APP_ID = tokens['app_id']
	SECRET_KEY = tokens['secret_key']
	CALLBACK_URL = tokens['callback_url']
	PAGE_TAB_APP_ID = tokens['page_tab_app_id']
	PAGE_TAB_SECRET_KEY = tokens['page_tab_app_secret']
	APP_ID_FALLBACK = tokens['app_id_fallback']
	SECRET_KEY_FALLBACK = tokens['secret_key_fallback']
	PAGE_TAB_APP_ID_FALLBACK = tokens['page_tab_app_id_fallback']
	PAGE_TAB_SECRET_KEY_FALLBACK = tokens['page_tab_app_secret_fallback']
  
  Koala.config.api_version = Facebook::Constants::GRAPH_API_VERSION
end
