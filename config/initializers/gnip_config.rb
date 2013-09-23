module GnipConfig
	config = File.join(Rails.root, 'config', 'gnip.yml')
	url = (YAML::load_file config)[Rails.env]

	PRODUCTION_RULES_URL = GnipRule::Client.new(url['rules_url'], url['user_name'], url['password'])

	REPLAY_RULES_URL = GnipRule::Client.new(url['replay_rules_url'], url['user_name'], url['password'])

	GNIP_SECRET_KEY = "4fad0a12edb87190ec7dab302e2a56aa"
end
