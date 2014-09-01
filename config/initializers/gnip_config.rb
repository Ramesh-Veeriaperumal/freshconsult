module GnipConfig
  include Gnip::Constants
  
	config = File.join(Rails.root, 'config', 'gnip.yml')
	URL = (YAML::load_file config)[Rails.env]
  
  source = SOURCE[:twitter]

	PRODUCTION_RULES_URL = GnipRule::Client.new(URL[source]['rules_url'], URL[source]['user_name'], URL[source]['password'])

	REPLAY_RULES_URL = GnipRule::Client.new(URL[source]['replay_rules_url'], URL[source]['user_name'], URL[source]['password'])

	GNIP_SECRET_KEY = "4fad0a12edb87190ec7dab302e2a56aa"

  RULE_CLIENTS = {
    source => {
      :production => GnipRule::Client.new(URL[source]['rules_url'], URL[source]['user_name'], URL[source]['password']),
      :replay => GnipRule::Client.new(URL[source]['replay_rules_url'], URL[source]['user_name'], URL[source]['password'])
    }
  }
end
