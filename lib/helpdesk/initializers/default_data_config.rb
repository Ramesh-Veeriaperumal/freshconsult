tokens = YAML::load_file(File.join(Rails.root, 'config', 'default_data.yml')).with_indifferent_access
DEFAULT_FORUM_DATA = tokens["default_forum"]