module KloutConfig
  config = File.join(Rails.root, 'config', 'klout.yml')
  tokens = (YAML::load_file config)[Rails.env]
  API_KEY = tokens['api_key']
end