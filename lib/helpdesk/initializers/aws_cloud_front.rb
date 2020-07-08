config_path = Rails.root.join('config', 'cloud_front.yml')
config = Psych.safe_load(ERB.new(File.read(config_path)).result, [], [], true)

CLOUD_FRONT_CONFIG = config[Rails.env].symbolize_keys
