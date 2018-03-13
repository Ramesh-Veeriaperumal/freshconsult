module SmartFilterConfig
  config = File.join(Rails.root, 'config', 'smart_filter.yml')
  tokens = YAML::load_file(config)
  API_ENDPOINT = tokens[Rails.env]['api_endpoint']
  AUTH_KEY = tokens[Rails.env]['auth_key']
  INIT_URL = tokens[Rails.env]['init_url']
  QUERY_URL = tokens[Rails.env]['query_url']
  FEEDBACK_URL = tokens[Rails.env]['feedback_url']
  MAX_TRIES = tokens[Rails.env]['max_tries']
end