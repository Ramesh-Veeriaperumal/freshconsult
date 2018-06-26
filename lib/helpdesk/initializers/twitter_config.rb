module TwitterConfig
  config = File.join(Rails.root, 'config', 'twitter.yml')
  tokens = YAML::load_file config
  CLIENT_ID       = tokens['consumer_token'][Rails.env]['default']
  CLIENT_SECRET   = tokens['consumer_secret'][Rails.env]['default']
  CLIENT_ID_FALLBACK       = tokens['consumer_token'][Rails.env]['fallback']
  CLIENT_SECRET_FALLBACK   = tokens['consumer_secret'][Rails.env]['fallback']
  TWITTER_TIMEOUT = tokens['twitter_timeout'][Rails.env]
end
