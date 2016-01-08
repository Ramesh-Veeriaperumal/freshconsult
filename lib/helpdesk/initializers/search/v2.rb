### Getting supported types from the config file provided by product ###

ES_V2_SUPPORTED_TYPES = YAML.load_file(File.join(Rails.root, 'config/search/supported_types.yml'))
ES_V2_BOOST_VALUES    = YAML::load_file(File.join(Rails.root, 'config/search', 'boost_values.yml'))
ES_V2_CLUSTERS        = YAML::load_file(File.join(Rails.root, 'config/search', 'esv2_hosts.yml'))[Rails.env].symbolize_keys