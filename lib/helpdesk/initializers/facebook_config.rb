module FacebookConfig
	config = File.join(Rails.root, 'config', 'facebook.yml')
	tokens = (YAML::load_file config)[Rails.env]

	APP_ID = tokens['app_id']
	SECRET_KEY = tokens['secret_key']
	CALLBACK_URL = tokens['callback_url']
	PAGE_TAB_APP_ID = tokens['page_tab_app_id']
	PAGE_TAB_SECRET_KEY = tokens['page_tab_app_secret']

	APP_ID_EUC = tokens['app_id_euc']
	SECRET_KEY_EUC = tokens['secret_key_euc']
	PAGE_TAB_APP_ID_EUC = tokens['page_tab_app_id_euc']
	PAGE_TAB_SECRET_KEY_EUC = tokens['page_tab_app_secret_euc']

	APP_ID_EU = tokens['app_id_eu']
	SECRET_KEY_EU = tokens['secret_key_eu']
	PAGE_TAB_APP_ID_EU = tokens['page_tab_app_id_eu']
	PAGE_TAB_SECRET_KEY_EU = tokens['page_tab_app_secret_eu']
  
  Koala.config.api_version = Facebook::Constants::GRAPH_API_VERSION
end
