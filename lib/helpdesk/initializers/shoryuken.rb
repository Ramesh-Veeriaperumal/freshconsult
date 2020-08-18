SH_ENABLED = !(Rails.env.development? or Rails.env.test?) #=> To prevent error without setup
puts "Shoryuken is #{SH_ENABLED ? 'enabled' : 'not enabled'}"

if SH_ENABLED
  Shoryuken::EnvironmentLoader.setup_options(config_file: File.join(Rails.root, 'config/shoryuken.yml')) #PRE-RAILS: Shoryuken 4.x init config load is changed

  # Shoryuken.configure_client do |config|
  #   config.client_middleware do |chain|
  #     chain.add MyMiddleware
  #   end
  # end

  # https://github.com/phstc/shoryuken/wiki/Configure-the-AWS-Client
  Shoryuken.sqs_client =  Aws::SQS::Client.new(SQS_SDK2_CREDS)

  require 'prometheus_exporter/instrumentation' if ENV['ENABLE_PROMETHEUS'] == '1'
  Shoryuken.configure_server do |config|
    config.server_middleware do |chain|
      chain.add PrometheusExporter::Instrumentation::Shoryuken if ENV['ENABLE_PROMETHEUS'] == '1'
      chain.add Middleware::Shoryuken::Server::ResetThread
      chain.add Middleware::Shoryuken::Server::SupressSqlLogs
      chain.add Middleware::Shoryuken::Server::BelongsToAccount, :ignore => [
        'Ryuken::FacebookRealtime',
        'Email::MailFetchWorker',
        'Email::EmailDeadLetterWorker',
        'Ryuken::ChannelMessagePoller',
        'Bot::FeedbackPoller',
        'Ryuken::FreddyConsumedSessionReminder'
      ]
    end
    config.on :startup do
      PrometheusExporter::Instrumentation::Process.start type: 'shoryuken' if ENV['ENABLE_PROMETHEUS'] == '1'
    end
  end
end
