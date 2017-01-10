SH_ENABLED = !(Rails.env.development? or Rails.env.test?) #=> To prevent error without setup
puts "Shoryuken is #{SH_ENABLED ? 'enabled' : 'not enabled'}" 

if SH_ENABLED
  config_options = YAML.load(ERB.new(IO.read(File.join(Rails.root, 'config/shoryuken.yml'))).result).deep_symbolize_keys
  Shoryuken::EnvironmentLoader.load(config_options)

  # Shoryuken.configure_client do |config|
  #   config.client_middleware do |chain|
  #     chain.add MyMiddleware
  #   end
  # end

  Shoryuken.configure_server do |config|
    config.server_middleware do |chain|
      chain.add Middleware::Shoryuken::Server::BelongsToAccount, :ignore => [
        "Ryuken::FacebookRealtime",
        "Email::MailFetchWorker",
        "Email::EmailDeadLetterWorker"
      ]
    end
  end
end
