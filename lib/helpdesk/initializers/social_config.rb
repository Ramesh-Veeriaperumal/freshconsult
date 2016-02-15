module SocialConfig
  config = File.join(Rails.root, 'config', 'social.yml')
  tokens = YAML::load_file config
  
  DYNAMO_TIMEOUT = tokens[Rails.env]['dynamo_timeout']
end  
