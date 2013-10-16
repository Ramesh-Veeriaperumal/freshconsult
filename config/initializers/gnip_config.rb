module GnipConfig
	config = File.join(Rails.root, 'config', 'gnip.yml')
	URL = (YAML::load_file config)[Rails.env]

	PRODUCTION_RULES_URL = GnipRule::Client.new(URL['rules_url'], URL['user_name'], URL['password'])

	REPLAY_RULES_URL = GnipRule::Client.new(URL['replay_rules_url'], URL['user_name'], URL['password'])

	GNIP_SECRET_KEY = "4fad0a12edb87190ec7dab302e2a56aa"
end
