module FluffyClient
  fluffy_config = YAML.load_file(Rails.root.join(Rails.root, 'config', 'fluffy.yml'))[Rails.env]

  Fluffy.configure do |config|
    config.host = fluffy_config['host']
    config.username = fluffy_config['username']
    config.password = fluffy_config['password']
  end
  fluffy_fd_client = Fluffy::AccountsApi.new
  Fluffy::FRESHDESK = Fluffy::ApiWrapper.new(fluffy_fd_client)

  fd_email_config = Fluffy::Configuration.new do |config|
    config.host = fluffy_config['host']
    config.username = fluffy_config['fd_email_username']
    config.password = fluffy_config['fd_email_password']
  end
  email_api_client = Fluffy::ApiClient.new(fd_email_config)
  fluffy_fd_email_client = Fluffy::AccountsV2Api.new(email_api_client)

  Fluffy::FRESHDESK_EMAIL = Fluffy::V2ApiWrapper.new(fluffy_fd_email_client)
end
