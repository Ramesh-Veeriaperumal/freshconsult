tokens = YAML::load_file(File.join(Rails.root, 'config', 'default_data.yml')).with_indifferent_access
DEFAULT_FORUM_DATA = tokens["default_forum"]
DEFAULT_TICKET_DATA = tokens["default_ticket"]
INDUSTRY_MAPPING = tokens["industry_mapping"]