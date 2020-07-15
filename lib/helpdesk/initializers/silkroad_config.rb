SILKROAD_CONFIG = YAML.load_file(Rails.root.join('config', 'silkroad_config.yml'))[Rails.env].symbolize_keys
