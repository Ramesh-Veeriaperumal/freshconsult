module TwitterConfig
  config = File.join(Rails.root, 'config', 'twitter.yml')
  tokens = YAML::load_file config
  CLIENT_ID       = tokens['consumer_token'][Rails.env]
  CLIENT_SECRET   = tokens['consumer_secret'][Rails.env]
  TWITTER_TIMEOUT = tokens['twitter_timeout'][Rails.env]
end
