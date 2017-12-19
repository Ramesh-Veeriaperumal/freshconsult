module ZendeskAppConfig
  config = File.join(Rails.root, 'config', 'zendesk_app.yml')
  tokens = YAML::load_file(config)
  APP_ID = tokens[Rails.env]['app_id']
  FALCON_APP_ID = tokens[Rails.env]['falcon_app_id']
end