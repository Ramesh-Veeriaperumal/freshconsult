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
  require 'prometheus_exporter/instrumentation' if ENV['ENABLE_PROMETHEUS'] == '1'
  Shoryuken.configure_server do |config|
    config.server_middleware do |chain|
      chain.add PrometheusExporter::Instrumentation::Shoryuken if ENV['ENABLE_PROMETHEUS'] == '1'
      chain.add Middleware::Shoryuken::Server::SupressSqlLogs
      chain.add Middleware::Shoryuken::Server::BelongsToAccount, :ignore => [
        'Ryuken::FacebookRealtime',
        'Email::MailFetchWorker',
        'Email::EmailDeadLetterWorker',
        'Ryuken::ChannelMessagePoller',
        'Bot::FeedbackPoller'
      ]
    end
    config.on :startup do
      PrometheusExporter::Instrumentation::Process.start type: 'shoryuken' if ENV['ENABLE_PROMETHEUS'] == '1'
    end
  end
end
