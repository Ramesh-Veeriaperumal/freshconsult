### Getting supported types from the config file provided by product ###

SUPPORTED_TYPES = YAML.load_file(File.join(Rails.root, 'config/search/supported_types.yml'))
